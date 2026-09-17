import QtQuick
import qs.services

QtObject {
    id: root

    // This object deliberately owns all mutable game state. The widget only renders
    // these arrays and calls these public methods through its explicit `game` id.
    property var configEntry: null
    property real boardWidth: 402
    property real boardHeight: 196
    property int gridSize: 24

    property bool paused: false
    property bool gameOver: false
    property bool soundEnabled: configEntry ? (configEntry.soundEnabled ?? true) : true
    onSoundEnabledChanged: if (configEntry) configEntry.soundEnabled = soundEnabled
    property int speedIndex: 0
    readonly property real speed: [1.0, 2.0, 4.0][speedIndex]
    property int wave: 0
    property int completedWaves: 0
    property int coins: 110
    property int lives: 20
    property int kills: 0
    property string phase: "intermission" // intermission | wave
    property real intermission: 0.8
    property real spawnTimer: 0
    property var spawnQueue: []
    property var enemies: []
    property var towers: []
    property var projectiles: []
    property var effects: []
    property int nextEnemyId: 1
    property int nextTowerId: 1
    property string buildType: ""
    property int selectedTowerId: -1
    property string message: "Choose a tower, then click clear grass."
    property real messageTime: 4
    property string bannerText: ""
    property real bannerTime: 0

    readonly property var selectedTower: towerById(selectedTowerId)
    readonly property int highScore: configEntry ? (configEntry.highScore || 0) : 0

    // The route is a set of game-space points and is the source of truth for both
    // movement and placement validation. It intentionally has no visual dependency.
    property var route: [
        { x: -18, y: 174 }, { x: 72, y: 174 }, { x: 72, y: 86 },
        { x: 202, y: 86 }, { x: 202, y: 132 }, { x: 326, y: 132 },
        { x: 326, y: 26 }, { x: 420, y: 26 }
    ]
    readonly property real pathLength: calculatePathLength()

    property var towerTypes: [
        { id: "bolt",  name: "Bolt",  short: "B", cost: 45, damage: 9,  range: 82,  rate: 0.52, projectileSpeed: 300, color: "#6ee7ff", slow: 0.0, splash: 0 },
        { id: "frost", name: "Frost", short: "F", cost: 55, damage: 5,  range: 76,  rate: 0.42, projectileSpeed: 250, color: "#a5b4fc", slow: 1.1, splash: 0 },
        { id: "cannon",name: "Cannon",short: "C", cost: 82, damage: 23, range: 98,  rate: 1.08, projectileSpeed: 180, color: "#fb923c", slow: 0.0, splash: 29 },
        { id: "arc",   name: "Arc",   short: "A", cost: 72, damage: 7,  range: 112, rate: 0.24, projectileSpeed: 410, color: "#f0abfc", slow: 0.0, splash: 0 }
    ]

    property var targetModes: ["First", "Closest", "Strongest", "Last"]

    property Timer simulationTimer: Timer {
        interval: 33
        repeat: true
        running: true
        onTriggered: root.step()
    }

    Component.onCompleted: restart()

    function calculatePathLength() {
        var total = 0
        for (var i = 0; i < route.length - 1; ++i) {
            var dx = route[i + 1].x - route[i].x
            var dy = route[i + 1].y - route[i].y
            total += Math.sqrt(dx * dx + dy * dy)
        }
        return total
    }

    function positionOnPath(distance) {
        var remaining = Math.max(0, distance)
        for (var i = 0; i < route.length - 1; ++i) {
            var a = route[i]
            var b = route[i + 1]
            var dx = b.x - a.x
            var dy = b.y - a.y
            var length = Math.sqrt(dx * dx + dy * dy)
            if (remaining <= length) {
                var ratio = length > 0 ? remaining / length : 0
                return { x: a.x + dx * ratio, y: a.y + dy * ratio }
            }
            remaining -= length
        }
        return route[route.length - 1]
    }

    function towerDefinition(type) {
        for (var i = 0; i < towerTypes.length; ++i) {
            if (towerTypes[i].id === type)
                return towerTypes[i]
        }
        return towerTypes[0]
    }

    function enemyDefinition(type) {
        var growth = 1 + Math.max(0, wave - 1) * 0.12
        if (type === "runner")
            return { type: type, hp: Math.round(26 * growth), speed: 64 + wave * 1.4, reward: 8, armour: 0, size: 11, color: "#facc15" }
        if (type === "swarm")
            return { type: type, hp: Math.round(15 * growth), speed: 50 + wave, reward: 4, armour: 0, size: 9, color: "#f472b6" }
        if (type === "armored")
            return { type: type, hp: Math.round(88 * growth), speed: 25 + wave * 0.35, reward: 14, armour: Math.floor(wave / 4) + 2, size: 15, color: "#94a3b8" }
        if (type === "boss")
            return { type: type, hp: Math.round((300 + wave * 34) * growth), speed: 20 + wave * 0.2, reward: 75 + wave * 3, armour: 4 + Math.floor(wave / 3), size: 20, color: "#ef4444" }
        return { type: "grunt", hp: Math.round(42 * growth), speed: 37 + wave * 0.7, reward: 7, armour: 0, size: 13, color: "#86efac" }
    }

    function enemyTypeForSlot(index, count) {
        if (wave % 5 === 0 && index === count - 1)
            return "boss"
        if (wave >= 4 && index % 7 === 0)
            return "armored"
        if (wave >= 3 && index % 5 === 0)
            return "runner"
        if (wave >= 2 && index % 3 === 0)
            return "swarm"
        return "grunt"
    }

    function startWave() {
        wave += 1
        var count = 5 + wave * 2
        var queue = []
        for (var i = 0; i < count; ++i)
            queue.push(enemyTypeForSlot(i, count))
        spawnQueue = queue
        spawnTimer = 0
        phase = "wave"
        var waveText = wave % 5 === 0 ? "BOSS WAVE " + wave + "!" : "WAVE " + wave
        setMessage(waveText + " incoming.", 2.2)
        showBanner(waveText, wave % 5 === 0 ? 3.0 : 1.8)
        playGameSound(wave % 5 === 0 ? "dialog-warning" : "complete")
    }

    function spawnEnemy(type) {
        var definition = enemyDefinition(type)
        var point = positionOnPath(0)
        var enemy = {
            id: nextEnemyId++, type: definition.type, hp: definition.hp, maxHp: definition.hp,
            speed: definition.speed, reward: definition.reward, armour: definition.armour,
            size: definition.size, color: definition.color, progress: 0, x: point.x, y: point.y,
            slowTime: 0, dead: false, hit: 0
        }
        enemies = enemies.concat([enemy])
    }

    function restart() {
        paused = false
        gameOver = false
        wave = 0
        completedWaves = 0
        coins = 110
        lives = 20
        kills = 0
        phase = "intermission"
        intermission = 0.8
        spawnTimer = 0
        spawnQueue = []
        enemies = []
        towers = []
        projectiles = []
        effects = []
        nextEnemyId = 1
        nextTowerId = 1
        buildType = ""
        selectedTowerId = -1
        setMessage("Defend the exit. Waves never end.", 3)
    }

    function setMessage(text, seconds) {
        message = text
        messageTime = seconds === undefined ? 2 : seconds
    }

    function playGameSound(name) {
        if (soundEnabled && Audio?.playSystemSound)
            Audio.playSystemSound(name)
    }

    function showBanner(text, seconds) {
        bannerText = text
        bannerTime = seconds === undefined ? 2.2 : seconds
    }

    function spawnEffect(x, y, color, size, label) {
        effects = effects.concat([{
            x: x, y: y, color: color, size: size || 10, label: label || "", life: 0.42, maxLife: 0.42
        }])
    }

    function nextWaveNow() {
        if (!gameOver && phase === "intermission")
            intermission = 0
    }

    function cycleSpeed() {
        speedIndex = (speedIndex + 1) % 3
        setMessage("Speed " + speed + "x", 1.2)
    }

    function selectBuild(type) {
        if (gameOver)
            return
        buildType = buildType === type ? "" : type
        selectedTowerId = -1
        setMessage(buildType === "" ? "Build selection cleared." : "Place " + towerDefinition(type).name + " on clear grass.", 1.8)
    }

    function snapX(x) {
        return Math.floor(Math.max(0, Math.min(boardWidth - 1, x)) / gridSize) * gridSize + gridSize / 2
    }

    function snapY(y) {
        return Math.floor(Math.max(0, Math.min(boardHeight - 1, y)) / gridSize) * gridSize + gridSize / 2
    }

    function pointSegmentDistance(px, py, ax, ay, bx, by) {
        var dx = bx - ax
        var dy = by - ay
        var lengthSquared = dx * dx + dy * dy
        if (lengthSquared <= 0)
            return Math.sqrt((px - ax) * (px - ax) + (py - ay) * (py - ay))
        var ratio = ((px - ax) * dx + (py - ay) * dy) / lengthSquared
        ratio = Math.max(0, Math.min(1, ratio))
        var cx = ax + ratio * dx
        var cy = ay + ratio * dy
        var ex = px - cx
        var ey = py - cy
        return Math.sqrt(ex * ex + ey * ey)
    }

    function canPlaceTower(x, y) {
        var sx = snapX(x)
        var sy = snapY(y)
        if (sx < 14 || sx > boardWidth - 14 || sy < 14 || sy > boardHeight - 14)
            return false
        for (var i = 0; i < route.length - 1; ++i) {
            if (pointSegmentDistance(sx, sy, route[i].x, route[i].y, route[i + 1].x, route[i + 1].y) < 22)
                return false
        }
        for (var j = 0; j < towers.length; ++j) {
            var dx = sx - towers[j].x
            var dy = sy - towers[j].y
            if (dx * dx + dy * dy < gridSize * gridSize)
                return false
        }
        return true
    }

    function towerAt(x, y) {
        for (var i = towers.length - 1; i >= 0; --i) {
            var dx = x - towers[i].x
            var dy = y - towers[i].y
            if (dx * dx + dy * dy <= 13 * 13)
                return towers[i]
        }
        return null
    }

    function handleBoardClick(x, y) {
        if (gameOver)
            return
        var hitTower = towerAt(x, y)
        if (hitTower) {
            selectedTowerId = hitTower.id
            buildType = ""
            setMessage(hitTower.target + " targeting selected.", 1.3)
            return
        }
        if (buildType === "") {
            selectedTowerId = -1
            return
        }
        var definition = towerDefinition(buildType)
        if (coins < definition.cost) {
            setMessage("Need $" + definition.cost + " for " + definition.name + ".", 1.7)
            return
        }
        if (!canPlaceTower(x, y)) {
            setMessage("Build on empty grass, away from the path.", 1.7)
            return
        }
        var tower = {
            id: nextTowerId++, type: definition.id, x: snapX(x), y: snapY(y), level: 1,
            cooldown: 0, target: "First", spent: definition.cost
        }
        towers = towers.concat([tower])
        coins -= definition.cost
        selectedTowerId = tower.id
        setMessage(definition.name + " built. Click it for upgrades.", 1.8)
    }

    function towerById(id) {
        for (var i = 0; i < towers.length; ++i) {
            if (towers[i].id === id)
                return towers[i]
        }
        return null
    }

    function towerStats(tower) {
        var definition = towerDefinition(tower.type)
        var levelBonus = tower.level - 1
        return {
            damage: Math.round(definition.damage * (1 + levelBonus * 0.34)),
            range: definition.range + levelBonus * 6,
            rate: Math.max(0.12, definition.rate * (1 - levelBonus * 0.055)),
            projectileSpeed: definition.projectileSpeed + levelBonus * 10,
            slow: definition.slow,
            splash: definition.splash + levelBonus * (definition.splash > 0 ? 2 : 0),
            color: definition.color
        }
    }

    function nextTowerStats(tower) {
        if (!tower || tower.level >= 5)
            return null
        return towerStats({ type: tower.type, level: tower.level + 1 })
    }

    function upgradeCost(tower) {
        if (!tower || tower.level >= 5)
            return 0
        return Math.round(towerDefinition(tower.type).cost * (0.55 + tower.level * 0.42))
    }

    function upgradeSelected() {
        var tower = selectedTower
        if (!tower)
            return
        if (tower.level >= 5) {
            setMessage("Tower is already level 5.", 1.5)
            return
        }
        var cost = upgradeCost(tower)
        if (coins < cost) {
            setMessage("Need $" + cost + " to upgrade.", 1.5)
            return
        }
        coins -= cost
        tower.level += 1
        tower.spent += cost
        towers = towers.slice()
        setMessage(towerDefinition(tower.type).name + " upgraded to level " + tower.level + ".", 1.5)
        playGameSound("complete")
    }

    function sellSelected() {
        var tower = selectedTower
        if (!tower)
            return
        var refund = Math.floor(tower.spent * 0.65)
        coins += refund
        towers = towers.filter(function(item) { return item.id !== tower.id })
        selectedTowerId = -1
        buildType = ""
        setMessage("Sold for $" + refund + ".", 1.3)
    }

    function cycleTargetMode() {
        var tower = selectedTower
        if (!tower)
            return
        var index = targetModes.indexOf(tower.target)
        tower.target = targetModes[(index + 1) % targetModes.length]
        towers = towers.slice()
        setMessage("Targeting: " + tower.target, 1.2)
    }

    function targetFor(tower, stats) {
        var chosen = null
        var chosenDistance = 0
        for (var i = 0; i < enemies.length; ++i) {
            var enemy = enemies[i]
            if (enemy.dead)
                continue
            var dx = enemy.x - tower.x
            var dy = enemy.y - tower.y
            var distance = Math.sqrt(dx * dx + dy * dy)
            if (distance > stats.range)
                continue
            if (!chosen) {
                chosen = enemy
                chosenDistance = distance
                continue
            }
            if (tower.target === "First" && enemy.progress > chosen.progress) {
                chosen = enemy
                chosenDistance = distance
            } else if (tower.target === "Last" && enemy.progress < chosen.progress) {
                chosen = enemy
                chosenDistance = distance
            } else if (tower.target === "Strongest" && enemy.hp > chosen.hp) {
                chosen = enemy
                chosenDistance = distance
            } else if (tower.target === "Closest" && distance < chosenDistance) {
                chosen = enemy
                chosenDistance = distance
            }
        }
        return chosen
    }

    function fireTower(tower, target, stats) {
        projectiles = projectiles.concat([{
            x: tower.x, y: tower.y, prevX: tower.x, prevY: tower.y, targetId: target.id, damage: stats.damage,
            speed: stats.projectileSpeed, color: stats.color, slow: stats.slow,
            splash: stats.splash, life: 1.15
        }])
    }

    function damageEnemy(enemy, damage, slow) {
        if (!enemy || enemy.dead)
            return
        var actualDamage = Math.max(1, Math.round(damage - enemy.armour))
        enemy.hp -= actualDamage
        enemy.hit = 0.12
        spawnEffect(enemy.x, enemy.y - enemy.size * 0.7, "#f8fafc", 8, "-" + actualDamage)
        if (slow > 0)
            enemy.slowTime = Math.max(enemy.slowTime, slow)
        if (enemy.hp <= 0) {
            enemy.dead = true
            coins += enemy.reward
            kills += 1
            spawnEffect(enemy.x, enemy.y, enemy.type === "boss" ? "#fb7185" : "#8be9fd", enemy.type === "boss" ? 28 : 14)
        }
    }

    function enemyById(id) {
        for (var i = 0; i < enemies.length; ++i) {
            if (enemies[i].id === id && !enemies[i].dead)
                return enemies[i]
        }
        return null
    }

    function updateEnemies(delta) {
        var survivors = []
        for (var i = 0; i < enemies.length; ++i) {
            var enemy = enemies[i]
            if (enemy.dead)
                continue
            enemy.hit = Math.max(0, enemy.hit - delta)
            enemy.slowTime = Math.max(0, enemy.slowTime - delta)
            var slowFactor = enemy.slowTime > 0 ? 0.48 : 1
            enemy.progress += enemy.speed * slowFactor * delta
            if (enemy.progress >= pathLength) {
                lives -= enemy.type === "boss" ? 4 : 1
                continue
            }
            var point = positionOnPath(enemy.progress)
            enemy.x = point.x
            enemy.y = point.y
            survivors.push(enemy)
        }
        enemies = survivors
        if (lives <= 0) {
            lives = 0
            gameOver = true
            playGameSound("suspend-error")
            updateHighScore()
            setMessage("The gate fell after wave " + wave + ".", 999)
        }
    }

    function updateProjectiles(delta) {
        var active = []
        for (var i = 0; i < projectiles.length; ++i) {
            var projectile = projectiles[i]
            projectile.life -= delta
            var target = enemyById(projectile.targetId)
            if (!target || projectile.life <= 0)
                continue
            var dx = target.x - projectile.x
            var dy = target.y - projectile.y
            var distance = Math.sqrt(dx * dx + dy * dy)
            var travel = projectile.speed * delta
            if (distance <= travel + 3) {
                damageEnemy(target, projectile.damage, projectile.slow)
                spawnEffect(target.x, target.y, projectile.color, projectile.splash > 0 ? projectile.splash : 9)
                if (projectile.splash > 0) {
                    for (var j = 0; j < enemies.length; ++j) {
                        var nearby = enemies[j]
                        if (nearby.id === target.id || nearby.dead)
                            continue
                        var sx = nearby.x - target.x
                        var sy = nearby.y - target.y
                        if (sx * sx + sy * sy <= projectile.splash * projectile.splash)
                            damageEnemy(nearby, projectile.damage * 0.55, projectile.slow)
                    }
                }
            } else {
                projectile.prevX = projectile.x
                projectile.prevY = projectile.y
                projectile.x += dx / distance * travel
                projectile.y += dy / distance * travel
                active.push(projectile)
            }
        }
        projectiles = active
    }

    function updateTowers(delta) {
        for (var i = 0; i < towers.length; ++i) {
            var tower = towers[i]
            tower.cooldown = Math.max(0, tower.cooldown - delta)
            var stats = towerStats(tower)
            var target = targetFor(tower, stats)
            if (target && tower.cooldown <= 0) {
                fireTower(tower, target, stats)
                tower.cooldown = stats.rate
            }
        }
        towers = towers.slice()
    }

    function livingEnemyCount() {
        var count = 0
        for (var i = 0; i < enemies.length; ++i) {
            if (!enemies[i].dead)
                count += 1
        }
        return count
    }

    function updateHighScore() {
        if (configEntry && completedWaves > (configEntry.highScore || 0))
            configEntry.highScore = completedWaves
    }

    function step() {
        if (paused || gameOver)
            return
        var delta = 0.033 * speed
        if (messageTime > 0)
            messageTime = Math.max(0, messageTime - delta)
        if (bannerTime > 0)
            bannerTime = Math.max(0, bannerTime - delta)

        if (effects.length > 0) {
            var liveEffects = []
            for (var effectIndex = 0; effectIndex < effects.length; ++effectIndex) {
                var effect = effects[effectIndex]
                effect.life -= delta
                if (effect.life > 0)
                    liveEffects.push(effect)
            }
            effects = liveEffects
        }

        if (phase === "intermission") {
            intermission -= delta
            if (intermission <= 0)
                startWave()
            return
        }

        if (spawnQueue.length > 0) {
            spawnTimer -= delta
            if (spawnTimer <= 0) {
                spawnEnemy(spawnQueue[0])
                spawnQueue = spawnQueue.slice(1)
                spawnTimer = spawnQueue.length > 0 ? 0.34 : 0
            }
        }

        updateEnemies(delta)
        if (gameOver)
            return
        updateProjectiles(delta)
        updateTowers(delta)

        if (spawnQueue.length === 0 && livingEnemyCount() === 0) {
            completedWaves = wave
            coins += 12 + Math.min(48, wave * 2)
            updateHighScore()
            phase = "intermission"
            intermission = 2.8
            setMessage("Wave " + wave + " cleared. Prepare the next one.", 2.4)
        }
    }
}
