extends RefCounted
## Shared, pure picture-name ordering for the pane and baked ground models.

## 같은 것으로 보여 일부러 같은 그림을 쓴다: 상한 찌그러진 통조림은
## 찌그러진 통조림, 곁 쪽지는 쪽지와 같다.
const ART_ALIAS: Dictionary = {
	"can_dented_bad": "can_dented", "note_side": "note_map",
}
## 약초 책의 줄 아이콘 book은 그냥 책의 id이기도 하다(그 그림은 it_book).
const ICON_ALIAS: Dictionary = {
	"book": "herbal_book",
}


static func candidates(id: String, icon: String = "") -> Array[String]:
	var result: Array[String] = []
	for candidate: String in [id, String(ART_ALIAS.get(id, "")), String(ICON_ALIAS.get(icon, "")), icon]:
		if not candidate.is_empty() and not result.has(candidate):
			result.append(candidate)
	return result
