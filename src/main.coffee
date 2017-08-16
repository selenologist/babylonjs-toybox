$(document).ready ->
    canvas = document.getElementById 'renderCanvas'
    engine = new BABYLON.Engine(canvas, true)
    
    createScene = () ->
        scene  = new BABYLON.Scene(engine)
        camera = new BABYLON.FreeCamera('camera1', new BABYLON.Vector3(0, 5, -10), scene)
        camera.setTarget(BABYLON.Vector3.Zero())
        camera.attachControl(canvas, false)
        light  = new BABYLON.HemisphericLight('light1', new BABYLON.Vector3(0, 1, 0), scene)
        sphere = BABYLON.Mesh.CreateSphere('sphere1', 16, 2, scene)
        sphere.position.y = 1
        ground = BABYLON.Mesh.CreateGround('ground1', 6, 6, 2, scene)
        return scene

    scene = createScene()

    engine.runRenderLoop(->
        scene.render()
    )

    window.addEventListener('resize', -> engine.resize())
