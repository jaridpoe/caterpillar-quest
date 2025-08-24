function love.load()
    worm = {
        segments = {},
        segmentLength = 10,
        speed = 3,
        angle = 0,
        wiggleSpeed = 2,
        wiggleAmount = 1.2,
        radius = 8
    }
    -- Start with three segments
    local startX = 150
    local startY = love.graphics.getHeight() / 2
    for i = 1, 3 do
        worm.segments[i] = {
            x = startX - (i-1) * worm.segmentLength,
            y = startY,
        }
    end

    rocks = {}
    rockTimer = 0
    rockInterval = 1.2

    grass = {}
    grassTimer = 0
    grassInterval = 2.0

    score = 0

    lives = 3 -- Start with 3 lives

    gameState = "play"

    moles = {}
    moleTimer = 0
    moleInterval = 3.5 -- Moles appear less frequently

    math.randomseed(os.time())
end

function spawnRock()
    local rock = {
        x = love.graphics.getWidth() + 30,
        y = math.random(60, love.graphics.getHeight() - 60),
        radius = math.random(18, 32),
        points = {}
    }
    local vertexCount = 8
    for i = 1, vertexCount do
        local angle = (2 * math.pi / vertexCount) * i
        local radius = rock.radius + math.random(-6, 6)
        local px = math.cos(angle) * radius
        local py = math.sin(angle) * radius
        table.insert(rock.points, {px, py})
    end
    table.insert(rocks, rock)
end

function spawnGrass()
    local g = {
        x = love.graphics.getWidth() + 30,
        y = math.random(40, love.graphics.getHeight() - 40),
        width = 12,
        height = 28
    }
    table.insert(grass, g)
end

function spawnMole()
    local mole = {
        x = love.graphics.getWidth() + 30,
        y = math.random(60, love.graphics.getHeight() - 60),
        radius = 22,
        vy = math.random(-60, 60) / 30 -- random vertical speed
    }
    table.insert(moles, mole)
end

function love.update(dt)
    if gameState == "gameover" then return end

    local head = worm.segments[1]

    -- Controls
    if love.keyboard.isDown("up") or love.keyboard.isDown("w") then
        head.y = head.y - worm.speed
    elseif love.keyboard.isDown("down") or love.keyboard.isDown("s") then
        head.y = head.y + worm.speed
    end
    if love.keyboard.isDown("left") or love.keyboard.isDown("a") then
        head.x = head.x - worm.speed
    elseif love.keyboard.isDown("right") or love.keyboard.isDown("d") then
        head.x = head.x + worm.speed
    end

    head.x = math.max(12, math.min(love.graphics.getWidth() - 12, head.x))
    head.y = math.max(20, math.min(love.graphics.getHeight() - 20, head.y))

    worm.angle = worm.angle + worm.wiggleSpeed * dt

    -- Move each segment to follow the previous one, with a horizontal wave
    for i = 2, #worm.segments do
        local prev = worm.segments[i-1]
        local seg = worm.segments[i]
        local dx = prev.x - seg.x
        local dy = prev.y - seg.y
        local dist = math.sqrt(dx*dx + dy*dy)
        local targetDist = worm.segmentLength
        if dist > 0 then
            seg.x = seg.x + (dx/dist) * (dist - targetDist)
            seg.y = seg.y + (dy/dist) * (dist - targetDist)
        end
        seg.x = seg.x + math.sin(worm.angle + i * 0.5) * worm.wiggleAmount * 4
    end

    -- Spawn rocks
    rockTimer = rockTimer + dt
    if rockTimer > rockInterval then
        spawnRock()
        rockTimer = 0
    end

    for i, rock in ipairs(rocks) do
        rock.x = rock.x - 2
    end

    for i = #rocks, 1, -1 do
        if rocks[i].x < -rocks[i].radius then
            table.remove(rocks, i)
        end
    end

    -- Spawn grass
    grassTimer = grassTimer + dt
    if grassTimer > grassInterval then
        spawnGrass()
        grassTimer = 0
    end

    for i, g in ipairs(grass) do
        g.x = g.x - 2
    end

    for i = #grass, 1, -1 do
        if grass[i].x < -grass[i].width then
            table.remove(grass, i)
        end
    end

    -- Spawn moles only if worm has 10 or more segments
    if #worm.segments >= 10 then
        moleTimer = moleTimer + dt
        if moleTimer > moleInterval then
            spawnMole()
            moleTimer = 0
        end
    else
        moleTimer = 0
        moles = {}
    end

    -- Move moles left
    for i, mole in ipairs(moles) do
        mole.x = mole.x - 2
    end

    for i = #moles, 1, -1 do
        if moles[i].x < -moles[i].radius then
            table.remove(moles, i)
        end
    end

    -- Collision detection (rocks)
    for i = #rocks, 1, -1 do
        local rock = rocks[i]
        local dx = head.x - rock.x
        local dy = head.y - rock.y
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist < worm.radius + rock.radius then
            table.remove(worm.segments, #worm.segments)
            lives = lives - 1
            -- Remove the rock so the worm passes through
            table.remove(rocks, i)
            if lives == 0 or #worm.segments == 0 then
                gameState = "gameover"
            end
            break -- Only process one collision per frame
        end
    end

    -- Collision detection (grass)
    for i = #grass, 1, -1 do
        local g = grass[i]
        local eaten = false
        for _, seg in ipairs(worm.segments) do
            local dx = seg.x - g.x
            local dy = seg.y - g.y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist < worm.radius + g.width then
                eaten = true
                break
            end
        end
        if eaten then
            table.remove(grass, i)
            score = score + 1
            -- Add a new segment at the end of the worm
            local last = worm.segments[#worm.segments]
            local angle = math.atan2(last.y - worm.segments[1].y, last.x - worm.segments[1].x)
            table.insert(worm.segments, {
                x = last.x - math.cos(angle) * worm.segmentLength,
                y = last.y - math.sin(angle) * worm.segmentLength
            })
            lives = lives + 1 -- Gain a life when eating grass
        end
    end

    -- Collision detection (moles)
    for i = #moles, 1, -1 do
        local mole = moles[i]
        local dx = worm.segments[1].x - mole.x
        local dy = worm.segments[1].y - mole.y
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist < worm.radius + mole.radius then
            -- Remove 3 segments and 3 lives (or as many as possible)
            local removeCount = math.min(3, #worm.segments)
            for _ = 1, removeCount do
                table.remove(worm.segments, #worm.segments)
                lives = lives - 1
            end
            table.remove(moles, i)
            if lives <= 0 or #worm.segments == 0 then
                gameState = "gameover"
            end
            break
        end
    end
end

function restartGame()
    worm = {
        segments = {},
        segmentLength = 10,
        speed = 3,
        angle = 0,
        wiggleSpeed = 2,
        wiggleAmount = 1.2,
        radius = 8
    }
    local startX = 150
    local startY = love.graphics.getHeight() / 2
    for i = 1, 3 do
        worm.segments[i] = {
            x = startX - (i-1) * worm.segmentLength,
            y = startY,
        }
    end

    rocks = {}
    rockTimer = 0
    rockInterval = 1.2

    grass = {}
    grassTimer = 0
    grassInterval = 2.0

    score = 0

    lives = 3 -- Reset lives to 3

    gameState = "play"

    moles = {}
    moleTimer = 0
end

function love.keypressed(key)
    if gameState == "gameover" and key == "space" then
        restartGame()
    end
end

function love.draw()
    -- Color gradient: head is dark green, tail is light green
    local headColor = {0.1, 0.5, 0.1}
    local tailColor = {0.7, 0.9, 0.2}
    local segmentCount = #worm.segments

    for i, seg in ipairs(worm.segments) do
        -- Interpolate color
        local t = (i - 1) / math.max(segmentCount - 1, 1)
        local r = headColor[1] + (tailColor[1] - headColor[1]) * t
        local g = headColor[2] + (tailColor[2] - headColor[2]) * t
        local b = headColor[3] + (tailColor[3] - headColor[3]) * t

        love.graphics.setColor(r, g, b)
        love.graphics.circle("fill", seg.x, seg.y, worm.radius)
        -- Draw legs (6 per segment)
        love.graphics.setColor(0.3, 0.2, 0.1)
        for l = -1, 1, 2 do
            for k = 1, 3 do
                local legY = seg.y + worm.radius + 2
                local legX = seg.x + l * (worm.radius - 2) * (k / 3)
                love.graphics.line(legX, legY, legX, legY + 6)
            end
        end
    end

    -- Draw caterpillar head (first segment, bigger and with antennae)
    local head = worm.segments[1]
    love.graphics.setColor(headColor[1], headColor[2], headColor[3])
    love.graphics.circle("fill", head.x, head.y, worm.radius + 3)
    -- Antennae
    love.graphics.setColor(0.3, 0.2, 0.1)
    love.graphics.line(head.x - 4, head.y - worm.radius - 2, head.x - 8, head.y - worm.radius - 12)
    love.graphics.line(head.x + 4, head.y - worm.radius - 2, head.x + 8, head.y - worm.radius - 12)
    love.graphics.setColor(headColor[1], headColor[2], headColor[3])
    love.graphics.circle("fill", head.x - 8, head.y - worm.radius - 12, 2)
    love.graphics.circle("fill", head.x + 8, head.y - worm.radius - 12, 2)

    -- Draw rocks as irregular polygons
    love.graphics.setColor(0.5, 0.4, 0.3)
    for _, rock in ipairs(rocks) do
        local points = {}
        local vertexCount = 8
        for i = 1, vertexCount do
            local angle = (2 * math.pi / vertexCount) * i
            local radius = rock.radius + math.random(-6, 6)
            local px = rock.x + math.cos(angle) * radius
            local py = rock.y + math.sin(angle) * radius
            table.insert(points, px)
            table.insert(points, py)
        end
        love.graphics.polygon("fill", points)
    end

    -- Draw grass
    love.graphics.setColor(0.3, 0.6, 0.3)
    for _, g in ipairs(grass) do
        love.graphics.rectangle("fill", g.x, g.y, g.width, g.height)
    end

    -- Draw moles
    love.graphics.setColor(0.5, 0.3, 0.1)
    for _, mole in ipairs(moles) do
        love.graphics.circle("fill", mole.x, mole.y, mole.radius)
        love.graphics.setColor(0.3, 0.2, 0.1)
        love.graphics.circle("fill", mole.x, mole.y + mole.radius / 2, mole.radius / 2)
        love.graphics.setColor(0.5, 0.3, 0.1)
    end

    -- Draw score and lives
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Score: " .. score, 10, 10)
    love.graphics.print("Lives: " .. lives, 10, 30)

    if gameState == "gameover" then
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("GAME OVER", 0, love.graphics.getHeight()/2 - 40, love.graphics.getWidth(), "center")
        love.graphics.printf("Score: " .. score, 0, love.graphics.getHeight()/2, love.graphics.getWidth(), "center")
        love.graphics.printf("Press SPACE to restart", 0, love.graphics.getHeight()/2 + 40, love.graphics.getWidth(), "center")
    end
end