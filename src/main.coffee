$(document).ready ->
    canvas = document.getElementById 'renderCanvas'
    engine = new BABYLON.Engine(canvas, true)
  
    attracted_to_origin = []
    ground = null
    createScene = () ->
        scene  = new BABYLON.Scene(engine)
        scene.enablePhysics()
        scene.fogMode = BABYLON.Scene.FOGMODE_EXP2
        scene.fogDensity = 0.02

        camera = new BABYLON.FreeCamera('camera1', new BABYLON.Vector3(0, 10, -20), scene)
        camera.setTarget(BABYLON.Vector3.Zero())
        #camera.attachControl(canvas, false)
        
        light  = new BABYLON.HemisphericLight('Sunlight', new BABYLON.Vector3(0, 1, 0), scene)
        light.intensity = 0.4
        light.diffuse = new BABYLON.Color3(1.0, 0.7, 0.4)

        cube = BABYLON.Mesh.CreateBox('cube1', 2, scene)
        cube.position.y = 3
        cube.material = new BABYLON.StandardMaterial("cube material", scene)
        cube.material.specularPower = 8
        cube.material.diffuseColor = new BABYLON.Color3(0.9, 0.1, 0.1)
        cube.physics =
            new BABYLON.PhysicsImpostor(cube,
                                        BABYLON.PhysicsImpostor.BoxImpostor,
                                        { mass: 1.0 },
                                        scene)

        cube2 = BABYLON.Mesh.CreateBox('cube2', 2, scene)
        cube2.position.y = 9
        cube2.material = new BABYLON.StandardMaterial("cube2 material", scene)
        cube2.material.specularPower = 4
        cube2.material.diffuseColor = new BABYLON.Color3(0.1, 0.9, 0.1)
        cube2.physics =
            new BABYLON.PhysicsImpostor(cube2,
                                        BABYLON.PhysicsImpostor.BoxImpostor,
                                        { mass: 0.5 },
                                        scene)

        sphere = BABYLON.Mesh.CreateSphere('sphere1', 10, 2, scene)
        sphere.position.y = 10
        sphere.material = new BABYLON.StandardMaterial("sphere material", scene)
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

        sphere.shadowGenerator = new BABYLON.ShadowGenerator(1024, sphere.pointLight)
        sphere.shadowGenerator.useBlurExponentialShadowMap = true
        shadowList = sphere.shadowGenerator.getShadowMap().renderList
        shadowList.push(cube)
        shadowList.push(cube2)

        cube.rotationQuaternion = new BABYLON.Quaternion(1,1,1,0)
        cube.physics.setLinearVelocity(new BABYLON.Vector3(0.1,0,0))

        ground = BABYLON.Mesh.CreateGround('ground1', 300, 300, 2, scene)
        ground.physics =
            new BABYLON.PhysicsImpostor(ground,
                                        BABYLON.PhysicsImpostor.BoxImpostor,
                                        { mass: 0.0 }, # mass of 0 = static object
                                        scene)
        ground.material = new BABYLON.StandardMaterial("ground material", scene)
        ground.material.diffuseTexture =
            new BABYLON.GrassProceduralTexture(
                "grass texture",
                1024,
                scene
            )
        ground.material.specularColor = new BABYLON.Color3(0,0,0) # no specular reflection
        ((tex) -> tex.uScale = tex.vScale = 4)(ground.material.diffuseTexture)
        ground.receiveShadows = true

        attracted_to_origin = [cube, cube2, sphere]
        return scene

    drag = {}
    groundPos = () ->
        # pick the position on the ground that a ray cast from the pixel at the current mouse cursor would intersect
        pick = scene.pick(scene.pointerX, scene.pointerY, (mesh) -> return mesh == ground)
        if pick.hit
            return pick.pickedPoint
        else
            return null

    onPointerDown = (evt) ->
        if evt.button != 0 # only consider left-mouse-button clicks
            return

        # pick anything other than the ground
        pick = scene.pick(scene.pointerX, scene.pointerY,  (mesh) -> return mesh != ground )
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
        
        drag.start = null

    canvas.addEventListener("pointerdown", onPointerDown, false)
    canvas.addEventListener("pointerup", onPointerUp, false)
    canvas.addEventListener("pointermove", onPointerMove, false)

    vmap = (vector, func) -> new BABYLON.Vector3(func(vector.x, 0), func(vector.y, 1), func(vector.z, 2))
    update = () ->
        for mesh in attracted_to_origin
            origin = new BABYLON.Vector3(0,0,0)
            diff   = origin.subtract(mesh.position)
            diff   = vmap(diff, (a) ->
                sign =
                    if a > 0
                        1
                    else if a < 0
                        -1
                    else
                        0
                sign * Math.log10(a * a + 1.0)) 
            mesh.physics.applyImpulse(diff, mesh.getAbsolutePosition())

    scene = createScene()

    engine.runRenderLoop(->
        scene.render()
        update()
    )

    window.addEventListener('resize', -> engine.resize())
