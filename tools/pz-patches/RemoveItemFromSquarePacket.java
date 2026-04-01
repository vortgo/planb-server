package zombie.network.packets;

import zombie.Lua.LuaEventManager;
import zombie.MapCollisionData;
import zombie.characters.Capability;
import zombie.core.Core;
import zombie.core.logger.LoggerManager;
import zombie.core.network.ByteBufferReader;
import zombie.core.network.ByteBufferWriter;
import zombie.core.raknet.UdpConnection;
import zombie.debug.DebugLog;
import zombie.debug.DebugType;
import zombie.inventory.InventoryItem;
import zombie.inventory.types.Radio;
import zombie.iso.IsoGridSquare;
import zombie.iso.IsoObject;
import zombie.iso.IsoWorld;
import zombie.iso.WorldObjectContextMenuConstant;
import zombie.iso.areas.isoregion.IsoRegions;
import zombie.iso.objects.IsoGenerator;
import zombie.iso.objects.IsoRadio;
import zombie.iso.objects.IsoWorldInventoryObject;
import zombie.network.GameClient;
import zombie.network.IConnection;
import zombie.network.JSONField;
import zombie.network.PacketSetting;
import zombie.network.PacketTypes;
import zombie.network.ServerMap;
import zombie.pathfind.PolygonalMap2;
import zombie.savefile.SavefileNaming;

@PacketSetting(ordering = 1, priority = 1, reliability = 3, requiredCapability = Capability.LoginOnServer, handlingType = 3)
public class RemoveItemFromSquarePacket implements INetworkPacket {

    @JSONField
    public int x;

    @JSONField
    public int y;

    @JSONField
    byte z;

    @JSONField
    public short index;

    @Override
    public void setData(Object... values) {
        IsoObject obj = (IsoObject) values[0];
        this.x = obj.getSquare().getX();
        this.y = obj.getSquare().getY();
        this.z = (byte) obj.getSquare().getZ();
        this.index = (short) obj.getObjectIndex();
    }

    public void set(IsoObject obj) {
        this.x = obj.getSquare().getX();
        this.y = obj.getSquare().getY();
        this.z = (byte) obj.getSquare().getZ();
        this.index = (short) obj.getObjectIndex();
    }

    @Override
    public void write(ByteBufferWriter b) {
        b.putInt(this.x);
        b.putInt(this.y);
        b.putByte(this.z);
        b.putShort(this.index);
    }

    @Override
    public void parse(ByteBufferReader b, IConnection connection) {
        this.x = b.getInt();
        this.y = b.getInt();
        this.z = b.getByte();
        this.index = b.getShort();
    }

    @Override
    public void processClient(UdpConnection connection) {
        if (IsoWorld.instance.currentCell == null) {
            return;
        }
        IsoGridSquare sq = IsoWorld.instance.currentCell.getGridSquare(this.x, this.y, (int) this.z);
        if (sq == null) {
            GameClient.instance.delayPacket(this.x, this.y, this.z);
            return;
        }
        if (this.index >= 0 && this.index < sq.getObjects().size()) {
            IsoObject o = sq.getObjects().get(this.index);
            handleRemoveRadio(o, sq);
            sq.RemoveTileObject(o, false);
            if (o instanceof IsoWorldInventoryObject) {
                IsoWorldInventoryObject isoWorldInventoryObject = (IsoWorldInventoryObject) o;
                if (isoWorldInventoryObject.getItem() != null) {
                    isoWorldInventoryObject.getItem().setWorldItem(null);
                }
            }
            if ((o instanceof IsoWorldInventoryObject) || o.getContainer() != null) {
                LuaEventManager.triggerEvent("OnContainerUpdate", o);
                return;
            }
            return;
        }
        if (Core.debug) {
            DebugLog.log("RemoveItemFromSquare: sq is null or index is invalid %d,%d,%d index=%d".formatted(Integer.valueOf(this.x), Integer.valueOf(this.y), Byte.valueOf(this.z), Short.valueOf(this.index)));
        }
    }

    @Override
    public void processServer(PacketTypes.PacketType packetType, UdpConnection connection) {
        removeItemFromMap(connection, this.x, this.y, this.z, this.index);
        sendToRelativeClients(PacketTypes.PacketType.RemoveItemFromSquare, connection, this.x, this.y);
    }

    public static void removeItemFromMap(UdpConnection connection, int x, int y, int z, int index) {
        IsoGridSquare sq = IsoWorld.instance.currentCell.getGridSquare(x, y, z);
        if (sq != null && index >= 0 && index < sq.getObjects().size()) {
            IsoObject o = sq.getObjects().get(index);
            if (!(o instanceof IsoWorldInventoryObject)) {
                IsoRegions.setPreviousFlags(sq);
            }
            DebugLog.log(DebugType.Objects, "object: removing " + String.valueOf(o) + " index=" + index + " " + x + "," + y + "," + z);
            // PATCHED: log even when connection is null (NetTimedAction / Transaction path)
            String who = connection != null
                ? connection.getIDStr() + " \"" + connection.getUserName() + "\""
                : "\"server\"";
            if (o instanceof IsoWorldInventoryObject) {
                IsoWorldInventoryObject isoWorldInventoryObject = (IsoWorldInventoryObject) o;
                handleRemoveRadio(o, sq);
                LoggerManager.getLogger(WorldObjectContextMenuConstant.ITEM).write(who + " floor -1 " + x + "," + y + "," + z + " [" + isoWorldInventoryObject.getItem().getFullType() + "]");
            } else {
                String name = o.getName() != null ? o.getName() : o.getObjectName();
                if (o.getSprite() != null && o.getSprite().getName() != null) {
                    name = name + " (" + o.getSprite().getName() + ")";
                }
                LoggerManager.getLogger(SavefileNaming.SUBDIR_MAP).write(who + " removed " + name + " at " + x + "," + y + "," + z);
            }
            // END PATCH
            if (o.isTableSurface()) {
                for (int i = index + 1; i < sq.getObjects().size(); i++) {
                    IsoObject object = sq.getObjects().get(i);
                    if (object.isTableTopObject() || object.isTableSurface()) {
                        object.setRenderYOffset(object.getRenderYOffset() - o.getSurfaceOffset());
                    }
                }
            }
            if (!(o instanceof IsoWorldInventoryObject)) {
                LuaEventManager.triggerEvent("OnObjectAboutToBeRemoved", o);
            }
            if (!sq.getObjects().contains(o)) {
                throw new IllegalArgumentException("OnObjectAboutToBeRemoved not allowed to remove the object");
            }
            o.removeFromWorld();
            o.removeFromSquare();
            sq.RecalcAllWithNeighbours(true);
            if (!(o instanceof IsoWorldInventoryObject)) {
                IsoWorld.instance.currentCell.checkHaveRoof(x, y);
                MapCollisionData.instance.squareChanged(sq);
                PolygonalMap2.instance.squareChanged(sq);
                ServerMap.instance.physicsCheck(x, y);
                IsoRegions.squareChanged(sq, true);
                IsoGenerator.updateGenerator(sq);
            }
        }
    }

    private static void handleRemoveRadio(IsoObject o, IsoGridSquare sq) {
        Object idRadio;
        if (!(o instanceof IsoWorldInventoryObject)) {
            return;
        }
        IsoWorldInventoryObject isoWorldInventoryObject = (IsoWorldInventoryObject) o;
        InventoryItem invItem = isoWorldInventoryObject.getItem();
        if (invItem == null || !(invItem instanceof Radio)) {
            return;
        }
        for (int i = sq.getObjects().size() - 1; i >= 0; i--) {
            IsoObject objI = sq.getObjects().get(i);
            if ((objI instanceof IsoRadio) && !objI.getModData().isEmpty() && (idRadio = objI.getModData().rawget("RadioItemID")) != null && (idRadio instanceof Double)) {
                Double d = (Double) idRadio;
                if (d.intValue() == invItem.getID()) {
                    sq.RemoveTileObject(objI, false);
                    sq.RecalcAllWithNeighbours(true);
                    return;
                }
            }
        }
    }
}
