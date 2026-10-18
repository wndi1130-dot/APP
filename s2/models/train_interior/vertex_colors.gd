@tool
extends EditorScenePostImport
## GLB는 재질 없이 Col만 저장한다. 가져온 내장 재질에서 그 색을 켠다.

func _post_import(scene: Node) -> Object:
    _paint(scene)
    return scene

func _paint(node: Node) -> void:
    if node is MeshInstance3D:
        var mesh := (node as MeshInstance3D).mesh
        for surface in mesh.get_surface_count():
            var material := StandardMaterial3D.new()
            material.vertex_color_use_as_albedo = true
            material.vertex_color_is_srgb = false
            material.albedo_color = Color.WHITE
            material.roughness = 1.0
            mesh.surface_set_material(surface, material)
    for child in node.get_children():
        _paint(child)
