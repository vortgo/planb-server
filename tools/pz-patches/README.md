# PZ Server Java Patches

Патчи для `projectzomboid.jar` исправляющие баги серверного логирования в Build 42.

## RemoveItemFromSquarePacket.java

**Проблема:** Логи `map` и `item` не создаются — `GameServer.RemoveItemFromMap()` передаёт `null` вместо connection в `removeItemFromMap()`, логирование пропускается.

**Исправление:** Логирование срабатывает всегда, при `connection == null` пишет `"server"` вместо steamID.

### Применение

```bash
# На сервере — нужен JDK 25 (class format version 69)
# Скачать Zulu JDK 25:
cd /tmp && curl -sL 'https://cdn.azul.com/zulu/bin/zulu25.30.17-ca-jdk25.0.1-linux_x64.tar.gz' -o jdk25.tar.gz && tar xzf jdk25.tar.gz
JAVAC=/tmp/zulu25.30.17-ca-jdk25.0.1-linux_x64/bin/javac
JAR_TOOL=/tmp/zulu25.30.17-ca-jdk25.0.1-linux_x64/bin/jar
PZ_JAR=/home/pzserver/pz-server/java/projectzomboid.jar

# Бэкап
cp $PZ_JAR ${PZ_JAR}.bak

# Компиляция
mkdir -p /tmp/pz-patch-out
$JAVAC -cp $PZ_JAR -d /tmp/pz-patch-out RemoveItemFromSquarePacket.java

# Замена класса
cd /tmp/pz-patch-out
$JAR_TOOL uf $PZ_JAR zombie/network/packets/RemoveItemFromSquarePacket.class

# Перезагрузка сервера
```

### Откат

```bash
cp /home/pzserver/pz-server/java/projectzomboid.jar.bak /home/pzserver/pz-server/java/projectzomboid.jar
```
