shuffle = (array) ->
    length = array.length - 1
    for i in [length..1]
        j = Math.floor(Math.random() * i)
        tmp = array[i]
        array[i] = array[j]
        array[j] = tmp
    array


$(document).ready ->
    docbody = (document.getElementsByTagName 'body')[0]
    canvas = document.getElementById 'renderCanvas'
    engine = new BABYLON.Engine(canvas, true)

    attracted_to_origin = []
    slowed_by_water     = []
    clickable           = []
    
    BABYLON.Mesh.prototype.DisplacementMapFromFloatBuffer = (buffer, width, height, scale) ->
        positions = @getVerticesData(BABYLON.VertexBuffer.PositionKind)
        normals   = @getVerticesData(BABYLON.VertexBuffer.NormalKind)
        uvs       = @getVerticesData(BABYLON.VertexBuffer.UVKind)
        position  = BABYLON.Vector3.Zero()
        normal    = BABYLON.Vector3.Zero()
        uv        = BABYLON.Vector2.Zero()
        for p, index in positions by 3
            BABYLON.Vector3.FromArrayToRef(positions, index, position)
            BABYLON.Vector3.FromArrayToRef(normals, index, normal)
            BABYLON.Vector2.FromArrayToRef(uvs, (index/3)*2, uv)
            u = (uv.x * width)|0
            v = (uv.y * height)|0
            pos = (v * width + u)|0
            displacement = buffer[pos] * scale

            normal.normalize()
            normal.scaleInPlace(displacement)
            position = position.add(normal)
            position.toArray(positions, index)
        BABYLON.VertexData.ComputeNormals(positions, @getIndices(), normals)
        @updateVerticesData(BABYLON.VertexBuffer.PositionKind, positions)
        @updateVerticesData(BABYLON.VertexBuffer.NormalKind, normals)
        @

    outOfBounds = (mesh) ->
        pos = mesh.position
        if Math.abs(pos.x) > 128 ||
           pos.y < 0 ||
           Math.abs(pos.z) > 128
            return true
        else
            return false

    flat_large_plane = null
    ground = null
    camera = null
    light = null
    sphere = null
    water = null
    waterParticles = null
    createScene = () ->
        scene  = new BABYLON.Scene(engine)
        scene.enablePhysics()
        
        scene.environmentTexture =
            new BABYLON.CubeTexture("/assets/vendor/babylonjs/assets/textures/skybox/TropicalSunnyDay", scene)
        skybox = scene.createDefaultSkybox(scene.environmentTexture, true, 512)
        skybox.position.y = -30

        light  = new BABYLON.SpotLight(
            'Sunlight',
            new BABYLON.Vector3(0, 384, 0), # posn
            new BABYLON.Vector3(0,  -1, 0), # direction
            0.9, # angle
            2.0, # exponent
            scene)

        flat_large_plane = BABYLON.Mesh.CreateGround('ground for raycasting', 1000, 1000, 2, scene)
        flat_large_plane.isVisible = false
        
        cube = BABYLON.Mesh.CreateBox 'cube1', 2, scene
        cube.position = new BABYLON.Vector3 -2, 10, 0
        
        cube2 = BABYLON.Mesh.CreateBox 'cube2', 2, scene
        cube2.position = new BABYLON.Vector3 2, 12, 0
        
        cube.material = new BABYLON.StandardMaterial("cube material", scene)
        cube.material.specularPower = 8
        cube.material.diffuseColor = new BABYLON.Color3(0.9, 0.1, 0.1)
        cube2.material = new BABYLON.StandardMaterial("cube2 material", scene)
        cube2.material.specularPower = 4
        cube2.material.diffuseColor = new BABYLON.Color3(0.1, 0.9, 0.1)
        
        cube.physics =
            new BABYLON.PhysicsImpostor(cube,
                                        BABYLON.PhysicsImpostor.BoxImpostor,
                                        { mass: 1.0 },
                                        scene)
        cube2.physics =
            new BABYLON.PhysicsImpostor(cube2,
                                        BABYLON.PhysicsImpostor.BoxImpostor,
                                        { mass: 0.5 },
                                        scene)

        sphere = BABYLON.Mesh.CreateSphere('sphere', 10, 2, scene)
        sphere.position.y = 10
        sphere.material = new BABYLON.StandardMaterial("sphere material", scene)
        sphere.material.backFaceCulling = true
        sphere.material.diffuseColor = new BABYLON.Color3(0.1, 0.1, 0.9)
        sphere.material.specularPower = 32
        sphere.material.emissiveColor = new BABYLON.Color3(0.4, 0.2, 0.6)
        sphere.physics =
            new BABYLON.PhysicsImpostor(sphere,
                                        BABYLON.PhysicsImpostor.SphereImpostor,
                                        { mass: 1.0 },
                                        scene)
        sphere.pointLight =
            new BABYLON.PointLight("sphere light",
                                   new BABYLON.Vector3(0,0,0), # set at origin - will be a child of sphere
                                   scene)
        sphere.pointLight.parent = sphere
        sphere.pointLight.diffuse = new BABYLON.Color3(0.4, 0.2, 1.0)
        sphere.pointLight.specular = new BABYLON.Color3(0.6, 0.4, 1.0)

        cylinder = BABYLON.MeshBuilder.CreateCylinder("cylinder", {}, scene)
        cylinder.position.y = 20
        cylinder.material = sphere.material.clone("cylinder material")
        cylinder.material.diffuseColor = new BABYLON.Color3(0.7, 0.1, 0.6)
        cylinder.material.emissiveColor = new BABYLON.Color3(0.2, 0.1, 0.4)
        cylinder.physics =
            new BABYLON.PhysicsImpostor(cylinder,
                                        BABYLON.PhysicsImpostor.CylinderImpostor,
                                        { mass: 1.0 },
                                        scene)
        
        shadowGenerator = new BABYLON.ShadowGenerator(1024, light)
        shadowGenerator.bias = 0.001
        shadowGenerator.usePoissonSampling = true
        shadowList = shadowGenerator.getShadowMap().renderList
        shadowList.push(cube)
        shadowList.push(cube2)
        shadowList.push(sphere)
        shadowList.push(cylinder)

        groundmap = Array(256*256).fill(0)
        for x in [0..255]
            for y in [0..255]
                    groundmap[256 * y + x] =
                        (Math.cos(x/128 * Math.PI + y/64 * Math.PI) + 1.0) * 7.0 +
                        (Math.cos(x/32 * Math.PI + Math.sin(y/32*Math.PI)) + 1.0) * 5.0

        ground = BABYLON.Mesh.CreateGround('ground1', 256, 256, 128, scene, true) # lots of subdivisions for displacing, and IS updatable
        ground.DisplacementMapFromFloatBuffer(groundmap, 256, 256, 1)
        groundmap = null
        shadowList.push(ground)
        ground.physics =
            new BABYLON.PhysicsImpostor(ground,
                                        BABYLON.PhysicsImpostor.HeightmapImpostor,
                                        { mass: 0.0 }, # mass of 0 = static object
                                        scene)
        ground.material = new BABYLON.StandardMaterial("ground material", scene)
        ground.material.diffuseTexture =
            new BABYLON.GrassProceduralTexture(
                "grass texture",
                256,
                scene
            )
        ground.material.specularColor = new BABYLON.Color3(0,0,0) # no specular reflection
        ((x) -> x.uScale = x.vScale = 10) ground.material.diffuseTexture
        ground.receiveShadows = true

        water = BABYLON.Mesh.CreateGround("water", 256, 256, 16, scene) # less subdivs
        waterMat = new BABYLON.WaterMaterial("water_material", scene)
        waterMat.bumpTexture = new BABYLON.Texture("/assets/vendor/babylonjs/assets/textures/waterbump.png", scene)
        waterMat.backFaceCulling = true
        waterMat.windForce  = 4.0
        waterMat.waveHeight = 0.7
        waterMat.bumpHeight = 0.1
        waterMat.waveLength = 1.0
        waterMat.addToRenderList(skybox)
        waterMat.addToRenderList(sphere)
        waterMat.addToRenderList(cube)
        waterMat.addToRenderList(cube2)
        water.material = waterMat
        waterMat.alpha = 0.7

        waterParticles = new BABYLON.ParticleSystem(
            "water particles", 2000, scene)
        waterParticles.updateSpeed *= 2
        waterParticles.particleTexture = new BABYLON.Texture("/assets/textures/watersplash.png", scene)
        waterParticles.blendMode = BABYLON.ParticleSystem.BLENDMODE_STANDARD
        waterParticles.color1 = new BABYLON.Color4(0.8, 0.9, 1.0, 1.0)
        waterParticles.color2 = new BABYLON.Color4(0.3, 0.7, 1.0, 1.0)
        waterParticles.colorDead = new BABYLON.Color4(0.2, 0.6, 1.0, 0.1)
        waterParticles.minSize = 0.04
        waterParticles.maxSize = 0.6
        waterParticles.minLifetime = 0.3
        waterParticles.maxLifetime = 0.7
        waterParticles.gravity = new BABYLON.Vector3(0, -9.81, 0)
        waterParticles.disposeOnStop = false

        attracted_to_origin = [cube]
        slowed_by_water     = [cube, cube2, sphere, cylinder]
        clickable           = [cube, cube2, sphere, cylinder]
        
        camera = new BABYLON.UniversalCamera("Camera", new BABYLON.Vector3(0, 30, -25), scene)
        camera.maxZ = 1000
        camera.attachControl(canvas)
       
        ###
        wall_material = new BABYLON.StandardMaterial("wall material", scene)
        wall_material.specularPower = 25
        wall_material.specularColor = BABYLON.Vector3.Zero()
        newWall = (x, z, rot) ->
            wall = new BABYLON.Mesh.CreatePlane("wall"+rot, 256, scene)
            wall.material = wall_material
            wall.position = new BABYLON.Vector3(x, -64, z)
            wall.rotationQuaternion = BABYLON.Quaternion.RotationYawPitchRoll(rot, 0, 0)
            wall.physics =
                new BABYLON.PhysicsImpostor(wall,
                                            BABYLON.PhysicsImpostor.BoxImpostor
                                            { mass: 0.0 }, # mass of 0 = static object
                                            scene)
            wall.visibility = 0.4
        newWall(   0.0, 128.0,         0.0)
        newWall( 128.0,   0.0,   Math.PI/2)
        newWall(   0.0,-128.0,   Math.PI  )
        newWall(-128.0,   0.0, 3*Math.PI/2)
        ###
        
        ##
        # Optimisation

        cube.material.freeze()
        cube.convertToUnIndexedMesh()
        cube2.material.freeze()
        cube2.convertToUnIndexedMesh()
        sphere.material.freeze()
        ground.material.freeze()
        ground.freezeWorldMatrix()
        cylinder.material.freeze()
        skybox.freezeWorldMatrix()
        skybox.convertToUnIndexedMesh()
        #skybox.material.freeze() - don't do this, bottom half of the box isn't rendered
       
        try_harder = false
        try_harder and BABYLON.SceneOptimizer.OptimizeAsync(
            scene,
            BABYLON.SceneOptimizerOptions.LowDegradationAllowed(),
            () -> console.log("optimisation success"),
            () -> console.log("optimisation failure"))

        return scene

    drag = {}
    groundPos = () ->
        # pick the position on the ground that a ray cast from the pixel at the current mouse cursor would intersect
        pick = scene.pick(scene.pointerX, scene.pointerY, (mesh) -> return mesh == flat_large_plane)
        if pick.hit
            return pick.pickedPoint
        else
            return null

    onPointerDown = (evt) ->
        if evt.button != 0 # only consider left-mouse-button clicks
            return

        pick = scene.pick(scene.pointerX, scene.pointerY,  (mesh) -> return mesh in clickable)
        if pick.hit
            drag.mesh = pick.pickedMesh
            drag.start = groundPos()

    onPointerMove = (evt) ->
        if drag.start
            current = drag.mesh.position
            target = groundPos()
            diff = target.subtract(current)
            drag.mesh.physics.setLinearVelocity(diff)
            drag.start = current

    onPointerUp = (evt) ->
        if evt.button != 0 # ignore buttons other than LMB
            return
        
        if drag.start
            drag.start = null

    onKeyDown = (evt) ->
        if evt.keyCode == 49 # '1'
            if scene.debugLayer.isVisible()
            else
                scene.debugLayer.show()

    canvas.addEventListener("pointerdown", onPointerDown, false)
    canvas.addEventListener("pointerup", onPointerUp, false)
    canvas.addEventListener("pointermove", onPointerMove, false)
    docbody.onkeydown = onKeyDown

    vmap = (vector, func) -> new BABYLON.Vector3(func(vector.x, 0), func(vector.y, 1), func(vector.z, 2))
    update = () ->
        for mesh in attracted_to_origin
            origin = new BABYLON.Vector3(0,mesh.position.y,0)
            diff   = origin.subtract(mesh.position)
            diff   = vmap(diff, (a) ->
                sign =
                    if a > 0
                        1
                    else if a < 0
                        -1
                    else
                        0
                sign * Math.log2(a * a + 1.0) * 0.07)
            mesh.physics.applyImpulse(diff, mesh.getAbsolutePosition())
        for mesh in shuffle(slowed_by_water) # shuffle to share the single particle emitter ;D
            minimum = mesh.getBoundingInfo().minimum
            min_y   = mesh.position.y + minimum.y
            if mesh.physics and min_y < 3.75
                old = mesh.physics.getLinearVelocity()
                depth = Math.log10(4.75 - min_y) # log10 + 1, max depth 10m
                factor = 1.0 - depth*0.05
                # dampen velocity in water as a factor of depth
                mesh.physics.setLinearVelocity(vmap(old, (a) -> a * factor))
                
                velocitySum = Math.log(Math.abs(old.x) + Math.abs(old.y) + Math.abs(old.z) + 1.0)
                if velocitySum < 1
                    velocitySum = 0
                else
                    waterParticles.minEmitPower = velocitySum / 8
                    waterParticles.maxEmitPower = velocitySum * 4
                    waterParticles.emitter = mesh
                    waterParticles.manualEmitCount = 45*depth*velocitySum
                    waterParticles.start()

                old = mesh.physics.getAngularVelocity()
                mesh.physics.setAngularVelocity(vmap(old, (a) -> a * factor))
        for mesh in scene.meshes
            if outOfBounds(mesh)
                mesh.position = new BABYLON.Vector3(0, 10, 0)

    scene = createScene()

    engine.runRenderLoop(->
        update()
        scene.render()
    )

    window.addEventListener('resize', -> engine.resize())
