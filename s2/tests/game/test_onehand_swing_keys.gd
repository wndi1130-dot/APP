extends "res://addons/gut/test.gd"
## 원본 리그의 몸 공간에서 24장과 장 사이의 손 경로를 검사한다.

const BodyBake = preload("res://scripts/body_bake.gd")
const Pose = preload("res://game/actors/person_pose.gd")
const Visual = preload("res://game/actors/person_visual.gd")
const FieldCamera = preload("res://game/field_game.gd")
const CAMERA_PITCH: float = FieldCamera.CAM_PITCH
const CAMERA_YAW: float = FieldCamera.CAM_YAW
## 고침 4 직전의 전체 키. 보호 자세만을 위한 구판과 표면 대조를 섞지 않는다.
const SURFACE_BASELINE_LAYERS: Dictionary = {
	"p_swing_one": {
		"steps": [
			["aim","thigh.L","shin.L",[0.12,-1,["keys",[[0,0.22],[0.28,0.16],[0.43478260869565216,0.49231471024778295],[0.45,0.5],[0.4782608695652174,0.4868717819264176],[0.52,0.48],[0.62,0.56],[0.7,0.54],[0.74,0.34],[0.7826,0.22]]]]],
			["aim","shin.L","foot.L",[0.1,-1,["keys",[[0,-0.12],[0.28,-0.1],[0.43478260869565216,-0.29547924132222525],[0.45,-0.3],[0.4782608695652174,-0.2967179454816044],[0.52,-0.31],[0.62,-0.4],[0.7,-0.38],[0.74,-0.2],[0.7826,-0.12]]]]],
			["aim","thigh.R","shin.R",[-0.14,-1,["keys",[[0,-0.12],[0.28,-0.22],[0.43478260869565216,0.043896975785004094],[0.45,0.05],[0.4782608695652174,0.0450769182224066],[0.52,0.04],[0.62,0.12],[0.7,0.1],[0.74,-0.04],[0.7826,-0.12]]]]],
			["aim","shin.R","foot.R",[-0.1,-1,["keys",[[0,-0.2],[0.28,-0.15],[0.43478260869565216,-0.34547924132222524],[0.45,-0.35],[0.4782608695652174,-0.34179486370401096],[0.52,-0.34],[0.62,-0.44],[0.7,-0.42],[0.74,-0.26],[0.7826,-0.2]]]]],
			["turn","hips","y",["keys",[[0,0.2],[0.14,-0.18],[0.36,0.15],[0.43478260869565216,0.15944635818196762],[0.45,0.1627575],[0.4782608695652174,0.16906302621845976],[0.52,0.18],[0.62,0.22],[0.7,0.2],[0.74,0.2],[0.7826,0.2]]]],
			["turn","spine","x",["keys",[[0,0.14],[0.28,-0.1],[0.43478260869565216,0.3300543309088956],[0.45,0.34],[0.4782608695652174,0.3252307546672198],[0.52,0.3],[0.62,0.4],[0.7,0.42],[0.74,0.22],[0.7826,0.14]]]],
			["turn","neck","x",["keys",[[0,-0.1],[0.28,-0.1],[0.43478260869565216,0.01728754479333515],[0.45,0.02],[0.4782608695652174,0.013435890963208796],[0.52,-0.02],[0.62,0.04],[0.7,0.06],[0.74,-0.06],[0.7826,-0.1]]]],
			["turn","chest","y",["keys",[[0,-0.2],[0.24,-0.6],[0.42,0.45],[0.43478260869565216,0.45310932812815624],[0.45,0.4618075801749271],[0.4782608695652174,0.48754027107208936],[0.52,0.5],[0.62,0.6],[0.7,0.6],[0.74,0.2],[0.7826,-0.2]]]],
			["aim","upper_arm.L","forearm.L",[["keys",[[0,0.25],[0.28,0.25],[0.45,0.25],[0.4782608695652174,0.25],[0.52,0.1],[0.62,0.1],[0.7,0.1],[0.74,0.25],[0.7826,0.25]]],["keys",[[0,-0.8],[0.28,-0.8],[0.45,-0.8],[0.4782608695652174,-0.8],[0.52,-0.55],[0.62,-0.55],[0.7,-0.55],[0.74,-0.8],[0.7826,-0.8]]],["keys",[[0,0.45],[0.28,0.35],[0.45,0.45],[0.4782608695652174,0.45],[0.52,-0.2],[0.62,-0.2],[0.7,-0.2],[0.74,0.45],[0.7826,0.45]]]]],
			["aim","forearm.L","hand.L",[["keys",[[0,-0.45],[0.28,-0.45],[0.45,-0.45],[0.4782608695652174,-0.45],[0.52,0.6],[0.62,0.6],[0.7,0.6],[0.74,-0.45],[0.7826,-0.45]]],["keys",[[0,0.35],[0.28,0.35],[0.45,0.35],[0.4782608695652174,0.35],[0.52,-0.3],[0.62,-0.3],[0.7,-0.3],[0.74,0.35],[0.7826,0.35]]],["keys",[[0,0.8],[0.28,0.7000000000000001],[0.45,0.8],[0.4782608695652174,0.8],[0.52,0.3],[0.62,0.3],[0.7,0.3],[0.74,0.8],[0.7826,0.8]]]]],
			["aim","upper_arm.R","forearm.R",[["keys",[[0,-0.55],[0.28,-0.8],[0.43478260869565216,0.27513582727223884],[0.45,0.3],[0.4782608695652174,0.38205136295989006],[0.52,0.45],[0.62,0.35],[0.7,0.3],[0.74,-0.4],[0.7826,-0.55]]],["keys",[[0,-0.35],[0.28,0.1],[0.43478260869565216,-0.43756791363611947],[0.45,-0.45],[0.4782608695652174,-0.425384591112033],[0.52,-0.65],[0.62,-0.9],[0.7,-0.92],[0.74,-0.55],[0.7826,-0.35]]],["keys",[[0,-0.25],[0.28,-0.5],[0.43478260869565216,0.9660943099166894],[0.45,1],[0.4782608695652174,0.91794863704011],[0.52,0.65],[0.62,0.75],[0.7,0.7],[0.74,0.15],[0.7826,-0.25]]]]],
			["aim","forearm.R","hand.R",[["keys",[[0,-0.05],[0.28,-0.25],[0.43478260869565216,0.2093762171072293],[0.45,0.22],[0.4782608695652174,0.29056417214550545],[0.55,0.4],[0.65,0.3],[0.7,0.25],[0.74,-0.2],[0.7826,-0.05]]],["keys",[[0,1],[0.28,0.8],[0.43478260869565216,-0.060108661817791065],[0.45,-0.08],[0.4782608695652174,-0.0832820545183956],[0.55,-0.6],[0.65,-0.85],[0.7,-0.88],[0.74,0.3],[0.7826,1]]],["keys",[[0,0.3],[0.28,-0.45],[0.43478260869565216,0.967224499586133],[0.45,1],[0.4782608695652174,0.934358909632088],[0.55,0.7],[0.65,0.2],[0.7,0.18],[0.74,0.6],[0.7826,0.3]]]]],
		],
		"sink": ["keys",[[0,0.07],[0.28,0.05500000000000001],[0.43478260869565216,0.1185307534297232],[0.45,0.12],[0.4782608695652174,0.1167179454816044],[0.52,0.115],[0.62,0.14],[0.7,0.145],[0.74,0.09],[0.7826,0.07]]],
	},
	"p_swing_back": {
		"steps": [
			["aim","thigh.L","shin.L",[0.12,-1,["keys",[[0,0.22],[0.24,0.16],[0.30434782608695654,0.4328818636571544],[0.33,0.5],[0.34782608695652173,0.49863281531683173],[0.4252549019607843,0.48],[0.5613333333333334,0.56],[0.6701960784313725,0.54],[0.7246274509803922,0.34],[0.7826,0.22]]]]],
			["aim","shin.L","foot.L",[0.1,-1,["keys",[[0,-0.12],[0.24,-0.1],[0.30434782608695654,-0.26051874332773794],[0.33,-0.3],[0.34782608695652173,-0.29965820382920794],[0.4252549019607843,-0.31],[0.5613333333333334,-0.4],[0.6701960784313725,-0.38],[0.7246274509803922,-0.2],[0.7826,-0.12]]]]],
			["aim","thigh.R","shin.R",[-0.14,-1,["keys",[[0,-0.12],[0.24,-0.22],[0.30434782608695654,-0.0032996965075537954],[0.33,0.05],[0.34782608695652173,0.049487305743811896],[0.4252549019607843,0.04],[0.5613333333333334,0.12],[0.6701960784313725,0.1],[0.7246274509803922,-0.04],[0.7826,-0.12]]]]],
			["aim","shin.R","foot.R",[-0.1,-1,["keys",[[0,-0.2],[0.24,-0.15],[0.30434782608695654,-0.3105187433277379],[0.33,-0.35],[0.34782608695652173,-0.3491455095730198],[0.4252549019607843,-0.34],[0.5613333333333334,-0.44],[0.6701960784313725,-0.42],[0.7246274509803922,-0.26],[0.7826,-0.2]]]]],
			["turn","hips","y",["keys",[[0,0.2],[0.1,0.18],[0.27,-0.15],[0.30434782608695654,-0.1511628488581807],[0.33,-0.15332116937963836],[0.34782608695652173,-0.15532215328154744],[0.4252549019607843,-0.14],[0.5613333333333334,-0.1],[0.6701960784313725,0],[0.7246274509803922,0.1],[0.7826,0.2]]]],
			["turn","spine","x",["keys",[[0,0.14],[0.24,-0.1],[0.30434782608695654,0.2531412353210235],[0.33,0.34],[0.34782608695652173,0.3384619172314357],[0.4252549019607843,0.3],[0.5613333333333334,0.4],[0.6701960784313725,0.42],[0.7246274509803922,0.22],[0.7826,0.14]]]],
			["turn","neck","x",["keys",[[0,-0.1],[0.24,-0.1],[0.30434782608695654,-0.0036887540033572475],[0.33,0.02],[0.34782608695652173,0.01931640765841586],[0.4252549019607843,-0.02],[0.5613333333333334,0.04],[0.6701960784313725,0.06],[0.7246274509803922,-0.06],[0.7826,-0.1]]]],
			["turn","chest","y",["keys",[[0,-0.2],[0.15,0.55],[0.30434782608695654,-0.44634437187936626],[0.31,-0.45],[0.33,-0.45181760000000004],[0.34782608695652173,-0.456175139442755],[0.4252549019607843,-0.5],[0.5613333333333334,-0.6],[0.6701960784313725,-0.62],[0.7246274509803922,-0.36],[0.7826,-0.2]]]],
			["aim","upper_arm.L","forearm.L",[["keys",[[0,0.25],[0.24,0.25],[0.33,0.25],[0.34782608695652173,0.25],[0.4252549019607843,0.35],[0.5613333333333334,0.35],[0.6701960784313725,0.35],[0.7246274509803922,0.25],[0.7826,0.25]]],["keys",[[0,-0.8],[0.24,-0.8],[0.33,-0.8],[0.34782608695652173,-0.8],[0.4252549019607843,-0.55],[0.5613333333333334,-0.55],[0.6701960784313725,-0.55],[0.7246274509803922,-0.8],[0.7826,-0.8]]],["keys",[[0,0.45],[0.24,0.35],[0.33,0.45],[0.34782608695652173,0.45],[0.4252549019607843,-0.2],[0.5613333333333334,-0.2],[0.6701960784313725,-0.2],[0.7246274509803922,0.45],[0.7826,0.45]]]]],
			["aim","forearm.L","hand.L",[["keys",[[0,-0.45],[0.24,-0.45],[0.33,-0.45],[0.34782608695652173,-0.45],[0.4252549019607843,0.6],[0.5613333333333334,0.6],[0.6701960784313725,0.6],[0.7246274509803922,-0.45],[0.7826,-0.45]]],["keys",[[0,0.35],[0.24,0.35],[0.33,0.35],[0.34782608695652173,0.35],[0.4252549019607843,-0.3],[0.5613333333333334,-0.3],[0.6701960784313725,-0.3],[0.7246274509803922,0.35],[0.7826,0.35]]],["keys",[[0,0.8],[0.24,0.7000000000000001],[0.33,0.8],[0.34782608695652173,0.8],[0.4252549019607843,0.3],[0.5613333333333334,0.3],[0.6701960784313725,0.3],[0.7246274509803922,0.8],[0.7826,0.8]]]]],
			["aim","upper_arm.R","forearm.R",[["keys",[[0,-0.55],[0.24,0.75],[0.30434782608695654,0.3888328275125897],[0.33,0.3],[0.34782608695652173,0.28120121060643616],[0.4252549019607843,-0.45],[0.5613333333333334,-0.8],[0.6701960784313725,-0.7],[0.7246274509803922,-0.55],[0.7826,-0.55]]],["keys",[[0,-0.35],[0.24,0.05],[0.30434782608695654,-0.3512968583193448],[0.33,-0.45],[0.34782608695652173,-0.4474365287190595],[0.4252549019607843,-0.65],[0.5613333333333334,-0.9],[0.6701960784313725,-0.92],[0.7246274509803922,-0.55],[0.7826,-0.35]]],["keys",[[0,-0.25],[0.24,0.2],[0.30434782608695654,0.8420749733109518],[0.33,1],[0.34782608695652173,0.9914550957301983],[0.4252549019607843,0.35],[0.5613333333333334,-0.18],[0.6701960784313725,-0.22],[0.7246274509803922,-0.1],[0.7826,-0.25]]]]],
			["aim","forearm.R","hand.R",[["keys",[[0,-0.05],[0.24,0.5],[0.30434782608695654,0.2752737593411669],[0.33,0.22],[0.34782608695652173,0.20513186657054497],[0.4660784313725491,-0.4],[0.602156862745098,-0.1],[0.6701960784313725,-0.1],[0.7246274509803922,-0.15],[0.7826,-0.05]]],["keys",[[0,1],[0.24,0.65],[0.30434782608695654,0.06410658685375659],[0.33,-0.08],[0.34782608695652173,-0.08034179617079207],[0.4660784313725491,-0.6],[0.602156862745098,-0.88],[0.6701960784313725,-0.91],[0.7246274509803922,0.3],[0.7826,1]]],["keys",[[0,0.3],[0.24,-0.3],[0.30434782608695654,0.7433718316302964],[0.33,1],[0.34782608695652173,0.9931640765841586],[0.4660784313725491,0.4],[0.602156862745098,-0.12],[0.6701960784313725,-0.18],[0.7246274509803922,0.45],[0.7826,0.3]]]]],
		],
		"sink": ["keys",[[0,0.07],[0.24,0.05500000000000001],[0.30434782608695654,0.10716859158151482],[0.33,0.12],[0.34782608695652173,0.11965820382920793],[0.4252549019607843,0.115],[0.5613333333333334,0.14],[0.6701960784313725,0.145],[0.7246274509803922,0.09],[0.7826,0.07]]],
	},
}

const PROTECTED_HAND_LAYERS: Dictionary = {
	"p_swing_one": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.12, -1, ["keys", [[0, 0.22], [0.28, 0.16], [0.43478260869565216, 0.49231471024778295], [0.45, 0.5], [0.4782608695652174, 0.4868717819264176], [0.52, 0.48], [0.62, 0.56], [0.7, 0.54], [0.74, 0.34], [0.7826, 0.22]]]]],
			["aim", "shin.L", "foot.L", [0.1, -1, ["keys", [[0, -0.12], [0.28, -0.1], [0.43478260869565216, -0.29547924132222525], [0.45, -0.3], [0.4782608695652174, -0.2967179454816044], [0.52, -0.31], [0.62, -0.4], [0.7, -0.38], [0.74, -0.2], [0.7826, -0.12]]]]],
			["aim", "thigh.R", "shin.R", [-0.14, -1, ["keys", [[0, -0.12], [0.28, -0.22], [0.43478260869565216, 0.043896975785004094], [0.45, 0.05], [0.4782608695652174, 0.0450769182224066], [0.52, 0.04], [0.62, 0.12], [0.7, 0.1], [0.74, -0.04], [0.7826, -0.12]]]]],
			["aim", "shin.R", "foot.R", [-0.1, -1, ["keys", [[0, -0.2], [0.28, -0.15], [0.43478260869565216, -0.34547924132222524], [0.45, -0.35], [0.4782608695652174, -0.34179486370401096], [0.52, -0.34], [0.62, -0.44], [0.7, -0.42], [0.74, -0.26], [0.7826, -0.2]]]]],
			["turn", "hips", "y", ["keys", [[0, 0.2], [0.14, -0.18], [0.36, 0.15], [0.43478260869565216, 0.15944635818196762], [0.45, 0.1627575], [0.4782608695652174, 0.16906302621845976], [0.52, 0.18], [0.62, 0.22], [0.7, 0.2], [0.74, 0.2], [0.7826, 0.2]]]],
			["turn", "spine", "x", ["keys", [[0, 0.14], [0.28, -0.1], [0.43478260869565216, 0.3300543309088956], [0.45, 0.34], [0.4782608695652174, 0.3252307546672198], [0.52, 0.3], [0.62, 0.4], [0.7, 0.42], [0.74, 0.22], [0.7826, 0.14]]]],
			["turn", "neck", "x", ["keys", [[0, -0.1], [0.28, -0.1], [0.43478260869565216, 0.01728754479333515], [0.45, 0.02], [0.4782608695652174, 0.013435890963208796], [0.52, -0.02], [0.62, 0.04], [0.7, 0.06], [0.74, -0.06], [0.7826, -0.1]]]],
			["turn", "chest", "y", ["keys", [[0, -0.2], [0.24, -0.6], [0.42, 0.45], [0.43478260869565216, 0.45310932812815624], [0.45, 0.4618075801749271], [0.4782608695652174, 0.48754027107208936], [0.52, 0.5], [0.62, 0.6], [0.7, 0.6], [0.74, 0.2], [0.7826, -0.2]]]],
			["aim", "upper_arm.L", "forearm.L", [["keys", [[0, 0.25], [0.28, 0.25], [0.45, 0.25], [0.4782608695652174, 0.25], [0.52, 0.1], [0.62, 0.1], [0.7, 0.1], [0.74, 0.25], [0.7826, 0.25]]], ["keys", [[0, -0.8], [0.28, -0.8], [0.45, -0.8], [0.4782608695652174, -0.8], [0.52, -0.55], [0.62, -0.55], [0.7, -0.55], [0.74, -0.8], [0.7826, -0.8]]], ["keys", [[0, 0.45], [0.28, 0.35], [0.45, 0.45], [0.4782608695652174, 0.45], [0.52, -0.2], [0.62, -0.2], [0.7, -0.2], [0.74, 0.45], [0.7826, 0.45]]]]],
			["aim", "forearm.L", "hand.L", [["keys", [[0, -0.45], [0.28, -0.45], [0.45, -0.45], [0.4782608695652174, -0.45], [0.52, 0.6], [0.62, 0.6], [0.7, 0.6], [0.74, -0.45], [0.7826, -0.45]]], ["keys", [[0, 0.35], [0.28, 0.35], [0.45, 0.35], [0.4782608695652174, 0.35], [0.52, -0.3], [0.62, -0.3], [0.7, -0.3], [0.74, 0.35], [0.7826, 0.35]]], ["keys", [[0, 0.8], [0.28, 0.7000000000000001], [0.45, 0.8], [0.4782608695652174, 0.8], [0.52, 0.3], [0.62, 0.3], [0.7, 0.3], [0.74, 0.8], [0.7826, 0.8]]]]],
			["aim", "upper_arm.R", "forearm.R", [["keys", [[0, -0.55], [0.28, -0.8], [0.43478260869565216, 0.27513582727223884], [0.45, 0.3], [0.4782608695652174, 0.38205136295989006], [0.52, 0.45], [0.62, 0.35], [0.7, 0.3], [0.74, -0.4], [0.7826, -0.55]]], ["keys", [[0, -0.35], [0.28, 0.1], [0.43478260869565216, -0.43756791363611947], [0.45, -0.45], [0.4782608695652174, -0.425384591112033], [0.52, -0.65], [0.62, -0.9], [0.7, -0.92], [0.74, -0.55], [0.7826, -0.35]]], ["keys", [[0, -0.25], [0.28, -0.5], [0.43478260869565216, 0.9660943099166894], [0.45, 1], [0.4782608695652174, 0.91794863704011], [0.52, 0.65], [0.62, 0.3], [0.7, 0.25], [0.74, 0.15], [0.7826, -0.25]]]]],
			["aim", "forearm.R", "hand.R", [["keys", [[0, -0.05], [0.28, -0.25], [0.43478260869565216, 0.2093762171072293], [0.45, 0.22], [0.4782608695652174, 0.29056417214550545], [0.55, 0.4], [0.65, 0.3], [0.7, 0.25], [0.74, -0.2], [0.7826, -0.05]]], ["keys", [[0, 1], [0.28, 0.8], [0.43478260869565216, -0.060108661817791065], [0.45, -0.08], [0.4782608695652174, -0.0832820545183956], [0.55, -0.6], [0.65, -0.85], [0.7, -0.88], [0.74, 0.3], [0.7826, 1]]], ["keys", [[0, 0.3], [0.28, -0.45], [0.43478260869565216, 0.967224499586133], [0.45, 1], [0.4782608695652174, 0.934358909632088], [0.55, 0.7], [0.65, 0.45], [0.7, 0.4], [0.74, 0.6], [0.7826, 0.3]]]]],
		],
		"sink": ["keys", [[0, 0.07], [0.28, 0.05500000000000001], [0.43478260869565216, 0.1185307534297232], [0.45, 0.12], [0.4782608695652174, 0.1167179454816044], [0.52, 0.115], [0.62, 0.14], [0.7, 0.145], [0.74, 0.09], [0.7826, 0.07]]],
	},
	"p_swing_back": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.12, -1, ["keys", [[0, 0.22], [0.24, 0.16], [0.30434782608695654, 0.4328818636571544], [0.33, 0.5], [0.34782608695652173, 0.49863281531683173], [0.4252549019607843, 0.48], [0.5613333333333334, 0.56], [0.6701960784313725, 0.54], [0.7246274509803922, 0.34], [0.7826, 0.22]]]]],
			["aim", "shin.L", "foot.L", [0.1, -1, ["keys", [[0, -0.12], [0.24, -0.1], [0.30434782608695654, -0.26051874332773794], [0.33, -0.3], [0.34782608695652173, -0.29965820382920794], [0.4252549019607843, -0.31], [0.5613333333333334, -0.4], [0.6701960784313725, -0.38], [0.7246274509803922, -0.2], [0.7826, -0.12]]]]],
			["aim", "thigh.R", "shin.R", [-0.14, -1, ["keys", [[0, -0.12], [0.24, -0.22], [0.30434782608695654, -0.0032996965075537954], [0.33, 0.05], [0.34782608695652173, 0.049487305743811896], [0.4252549019607843, 0.04], [0.5613333333333334, 0.12], [0.6701960784313725, 0.1], [0.7246274509803922, -0.04], [0.7826, -0.12]]]]],
			["aim", "shin.R", "foot.R", [-0.1, -1, ["keys", [[0, -0.2], [0.24, -0.15], [0.30434782608695654, -0.3105187433277379], [0.33, -0.35], [0.34782608695652173, -0.3491455095730198], [0.4252549019607843, -0.34], [0.5613333333333334, -0.44], [0.6701960784313725, -0.42], [0.7246274509803922, -0.26], [0.7826, -0.2]]]]],
			["turn", "hips", "y", ["keys", [[0, 0.2], [0.1, 0.18], [0.27, -0.15], [0.30434782608695654, -0.1511628488581807], [0.33, -0.15332116937963836], [0.34782608695652173, -0.15532215328154744], [0.4252549019607843, -0.14], [0.5613333333333334, -0.1], [0.6701960784313725, 0], [0.7246274509803922, 0.1], [0.7826, 0.2]]]],
			["turn", "spine", "x", ["keys", [[0, 0.14], [0.24, -0.1], [0.30434782608695654, 0.2531412353210235], [0.33, 0.34], [0.34782608695652173, 0.3384619172314357], [0.4252549019607843, 0.3], [0.5613333333333334, 0.4], [0.6701960784313725, 0.42], [0.7246274509803922, 0.22], [0.7826, 0.14]]]],
			["turn", "neck", "x", ["keys", [[0, -0.1], [0.24, -0.1], [0.30434782608695654, -0.0036887540033572475], [0.33, 0.02], [0.34782608695652173, 0.01931640765841586], [0.4252549019607843, -0.02], [0.5613333333333334, 0.04], [0.6701960784313725, 0.06], [0.7246274509803922, -0.06], [0.7826, -0.1]]]],
			["turn", "chest", "y", ["keys", [[0, -0.2], [0.15, 0.55], [0.30434782608695654, -0.44634437187936626], [0.31, -0.45], [0.33, -0.45181760000000004], [0.34782608695652173, -0.456175139442755], [0.4252549019607843, -0.5], [0.5613333333333334, -0.6], [0.6701960784313725, -0.62], [0.7246274509803922, -0.36], [0.7826, -0.2]]]],
			["aim", "upper_arm.L", "forearm.L", [["keys", [[0, 0.25], [0.24, 0.25], [0.33, 0.25], [0.34782608695652173, 0.25], [0.4252549019607843, 0.35], [0.5613333333333334, 0.35], [0.6701960784313725, 0.35], [0.7246274509803922, 0.25], [0.7826, 0.25]]], ["keys", [[0, -0.8], [0.24, -0.8], [0.33, -0.8], [0.34782608695652173, -0.8], [0.4252549019607843, -0.55], [0.5613333333333334, -0.55], [0.6701960784313725, -0.55], [0.7246274509803922, -0.8], [0.7826, -0.8]]], ["keys", [[0, 0.45], [0.24, 0.35], [0.33, 0.45], [0.34782608695652173, 0.45], [0.4252549019607843, -0.2], [0.5613333333333334, -0.2], [0.6701960784313725, -0.2], [0.7246274509803922, 0.45], [0.7826, 0.45]]]]],
			["aim", "forearm.L", "hand.L", [["keys", [[0, -0.45], [0.24, -0.45], [0.33, -0.45], [0.34782608695652173, -0.45], [0.4252549019607843, 0.6], [0.5613333333333334, 0.6], [0.6701960784313725, 0.6], [0.7246274509803922, -0.45], [0.7826, -0.45]]], ["keys", [[0, 0.35], [0.24, 0.35], [0.33, 0.35], [0.34782608695652173, 0.35], [0.4252549019607843, -0.3], [0.5613333333333334, -0.3], [0.6701960784313725, -0.3], [0.7246274509803922, 0.35], [0.7826, 0.35]]], ["keys", [[0, 0.8], [0.24, 0.7000000000000001], [0.33, 0.8], [0.34782608695652173, 0.8], [0.4252549019607843, 0.3], [0.5613333333333334, 0.3], [0.6701960784313725, 0.3], [0.7246274509803922, 0.8], [0.7826, 0.8]]]]],
			["aim", "upper_arm.R", "forearm.R", [["keys", [[0, -0.55], [0.24, 0.75], [0.30434782608695654, 0.3888328275125897], [0.33, 0.3], [0.34782608695652173, 0.28120121060643616], [0.4252549019607843, -0.45], [0.5613333333333334, -0.45], [0.6701960784313725, -0.4], [0.7246274509803922, -0.55], [0.7826, -0.55]]], ["keys", [[0, -0.35], [0.24, 0.05], [0.30434782608695654, -0.3512968583193448], [0.33, -0.45], [0.34782608695652173, -0.4474365287190595], [0.4252549019607843, -0.65], [0.5613333333333334, -0.9], [0.6701960784313725, -0.92], [0.7246274509803922, -0.55], [0.7826, -0.35]]], ["keys", [[0, -0.25], [0.24, 0.2], [0.30434782608695654, 0.8420749733109518], [0.33, 1], [0.34782608695652173, 0.9914550957301983], [0.4252549019607843, 0.35], [0.5613333333333334, -0.18], [0.6701960784313725, -0.22], [0.7246274509803922, -0.1], [0.7826, -0.25]]]]],
			["aim", "forearm.R", "hand.R", [["keys", [[0, -0.05], [0.24, 0.5], [0.30434782608695654, 0.2752737593411669], [0.33, 0.22], [0.34782608695652173, 0.20513186657054497], [0.4660784313725491, -0.4], [0.602156862745098, -0.25], [0.6701960784313725, -0.2], [0.7246274509803922, -0.15], [0.7826, -0.05]]], ["keys", [[0, 1], [0.24, 0.65], [0.30434782608695654, 0.06410658685375659], [0.33, -0.08], [0.34782608695652173, -0.08034179617079207], [0.4660784313725491, -0.6], [0.602156862745098, -0.88], [0.6701960784313725, -0.91], [0.7246274509803922, 0.3], [0.7826, 1]]], ["keys", [[0, 0.3], [0.24, -0.3], [0.30434782608695654, 0.7433718316302964], [0.33, 1], [0.34782608695652173, 0.9931640765841586], [0.4660784313725491, 0.4], [0.602156862745098, -0.12], [0.6701960784313725, -0.18], [0.7246274509803922, 0.45], [0.7826, 0.3]]]]],
		],
		"sink": ["keys", [[0, 0.07], [0.24, 0.05500000000000001], [0.30434782608695654, 0.10716859158151482], [0.33, 0.12], [0.34782608695652173, 0.11965820382920793], [0.4252549019607843, 0.115], [0.5613333333333334, 0.14], [0.6701960784313725, 0.145], [0.7246274509803922, 0.09], [0.7826, 0.07]]],
	},
	"p_ready_one": {
		"steps": [
			["aim", "thigh.L", "shin.L", [0.12, -1, 0.22]],
			["aim", "shin.L", "foot.L", [0.1, -1, -0.12]],
			["aim", "thigh.R", "shin.R", [-0.14, -1, -0.12]],
			["aim", "shin.R", "foot.R", [-0.1, -1, -0.2]],
			["turn", "hips", "y", 0.2],
			["turn", "spine", "x", 0.14],
			["turn", "neck", "x", -0.1],
			["turn", "chest", "y", -0.2],
			["aim", "upper_arm.R", "forearm.R", [-0.55, -0.35, -0.25]],
			["aim", "forearm.R", "hand.R", [-0.05, 1, 0.3]],
			["aim", "upper_arm.L", "forearm.L", [0.25, -0.8, 0.45]],
			["aim", "forearm.L", "hand.L", [-0.45, 0.35, 0.8]],
		],
		"sink": 0.07,
	},
}

const SOURCE_RIGS: Array[String] = [
	"driver", "duffel_b1v2", "fitter", "guard", "guard_f", "hunter_f", "lumberjack",
	"medic", "overalls", "railman_old", "seamstress", "sheepskin", "stoker", "woodsman",
]
const CLIPS: Array[String] = ["p_swing_one", "p_swing_back"]
const FRAMES: int = 24
const GUARD: float = 18.0 / 23.0
const MIN_HAND_GAP: float = 0.25
const GUARD_TOLERANCE: float = 0.01
const STILL_SPEED: float = 0.05
const MAX_STILL_SECONDS: float = 0.15
const SURFACE_HEIGHT: float = 0.04
const SURFACE_SECTORS: int = 12
const SURFACE_MARGIN: float = 0.01
## The first swing keeps its protected hand keys at 10/23 and 11/23 (coordinator 11-06,
## combat hand-target IK fix 4). Sampled between those two baked frames at 60 fps the hand
## gap may dip, by at most the measured 25.83 mm (railman_old 25.827 mm, 11-05 bake 4);
## any other clip, rate, frame count, phase or a larger dip still fails the opening check.
const PROTECTED_DIP_CLIP: String = "p_swing_one"
const PROTECTED_DIP_FPS: int = 60
const PROTECTED_DIP_FROM: float = 10.0 / 23.0
const PROTECTED_DIP_TO: float = 11.0 / 23.0
const PROTECTED_DIP_MAX: float = 0.02583

var _motion: Node3D
var _source_dir: String
var _checked: Array[String] = []
var _handle_span := Vector2(NAN, NAN)


func _source_scene(path: String) -> Node3D:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(path, state)
	assert_eq(error, OK, "F-SOURCE-IMPORT " + path)
	return document.generate_scene(state) as Node3D if error == OK else null


func before_all() -> void:
	_source_dir = OS.get_environment("ONEHAND_SOURCE_ROOT")
	if _source_dir.is_empty():
		_source_dir = ProjectSettings.globalize_path("res://").path_join("../../_motion_src").simplify_path()
	var path := _source_dir.path_join("UAL1.glb")
	assert_true(FileAccess.file_exists(path), "F-INPUT-MISSING " + path)
	if not FileAccess.file_exists(path):
		return
	_motion = _source_scene(path)
	if _motion != null:
		add_child(_motion)
	_handle_span = _measure_handle_span()


func after_all() -> void:
	if _motion != null:
		_motion.free()
		_motion = null


func _entry(clip: String) -> Array:
	for entry: Array in BodyBake.PERSON_CLIPS:
		if entry[0] == clip:
			return entry
	assert_true(false, "F-CLIP-MISSING " + clip)
	return []


func _descends_from(body: Skeleton3D, bone: int, ancestor: int) -> bool:
	while bone >= 0:
		if bone == ancestor:
			return true
		bone = body.get_bone_parent(bone)
	return false


func _vertex_groups(ctx: Dictionary, arrays: Array) -> Dictionary:
	var body: Skeleton3D = ctx["body"]
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var binds: Array = ctx["bind_bone"]
	var per := int(bones.size() / vertices.size())
	var left := BodyBake._bone(body, "hand.L")
	var right := BodyBake._bone(body, "hand.R")
	var arm := BodyBake._bone(body, "forearm.L")
	var torso: Array[int] = [BodyBake._bone(body, "hips"), BodyBake._bone(body, "spine"), BodyBake._bone(body, "chest")]
	var groups := {"left": PackedInt32Array(), "right": PackedInt32Array(), "free_arm": PackedInt32Array(), "torso": PackedInt32Array()}
	for id in vertices.size():
		var sums := [0.0, 0.0, 0.0, 0.0]
		for influence in per:
			var at := id * per + influence
			if weights[at] <= 0.0:
				continue
			var bone: int = binds[bones[at]]
			if _descends_from(body, bone, left):
				sums[0] += weights[at]
			if _descends_from(body, bone, right):
				sums[1] += weights[at]
			if _descends_from(body, bone, arm):
				sums[2] += weights[at]
			if bone in torso:
				sums[3] += weights[at]
		for slot in 4:
			if sums[slot] >= 0.5:
				var group_name: String = ["left", "right", "free_arm", "torso"][slot]
				var ids: PackedInt32Array = groups[group_name]
				ids.append(id)
				groups[group_name] = ids
	return groups


func _joint(ctx: Dictionary, root: Node3D, name_text: String) -> Vector3:
	var body: Skeleton3D = ctx["body"]
	return root.global_transform.affine_inverse() * BodyBake._world(body, BodyBake._bone(body, name_text)).origin


## 같은 장의 몸통 표면을 높이 4 cm, 둘레 30도 구간으로 나눈다.
static func torso_surface(points: PackedVector3Array, hips: Vector3, chest: Vector3) -> Dictionary:
	var axis := chest - hips
	if points.is_empty() or not is_finite(axis.length_squared()) or axis.length_squared() < 0.00000001:
		return {"valid": false, "reason": "empty torso or invalid axis"}
	axis = axis.normalized()
	var forward := Vector3.BACK - axis * axis.dot(Vector3.BACK)
	if forward.length_squared() < 0.00000001:
		forward = Vector3.RIGHT - axis * axis.dot(Vector3.RIGHT)
	forward = forward.normalized()
	var surface := {
		"valid": true, "origin": hips, "axis": axis, "forward": forward,
		"left": axis.cross(forward).normalized(), "cells": {},
		"height_low": INF, "height_high": -INF,
	}
	var cells: Dictionary = surface["cells"]
	for point in points:
		if not is_finite(point.length_squared()):
			return {"valid": false, "reason": "non-finite torso vertex"}
		var sample := _surface_coordinates(surface, point)
		var cell: Vector2i = sample["cell"]
		cells[cell] = maxf(float(cells.get(cell, 0.0)), float(sample["radius"]))
		surface["height_low"] = minf(float(surface["height_low"]), float(sample["height"]))
		surface["height_high"] = maxf(float(surface["height_high"]), float(sample["height"]))
	surface["cells"] = cells
	return surface


static func _surface_coordinates(surface: Dictionary, point: Vector3) -> Dictionary:
	var delta := point - (surface["origin"] as Vector3)
	var axis: Vector3 = surface["axis"]
	var height := delta.dot(axis)
	var radial := delta - axis * height
	var angle := atan2(radial.dot(surface["left"]), radial.dot(surface["forward"]))
	var sector := posmod(int(floorf(angle / (TAU / float(SURFACE_SECTORS)) + 0.5)), SURFACE_SECTORS)
	return {"height": height, "radius": radial.length(), "cell": Vector2i(int(floorf(height / SURFACE_HEIGHT)), sector)}


## 빈 구간은 높이·둘레의 가장 가까운 구간으로 채우고, 동률이면 큰 반지름을 쓴다.
static func surface_clearance(surface: Dictionary, point: Vector3) -> Dictionary:
	if not bool(surface.get("valid", false)) or not is_finite(point.length_squared()):
		return {"valid": false, "inside": false, "reason": "invalid surface or point"}
	var sample := _surface_coordinates(surface, point)
	var cell: Vector2i = sample["cell"]
	var height: float = sample["height"]
	if height < float(surface["height_low"]) or height > float(surface["height_high"]):
		return {"valid": true, "inside": false, "clearance": INF, "radius": 0.0, "cell": cell, "source_cell": cell, "fallback": false}
	var cells: Dictionary = surface["cells"]
	var fallback := not cells.has(cell)
	var radius := float(cells.get(cell, 0.0))
	var source_cell := cell
	if fallback:
		var nearest := 2147483647
		for occupied: Vector2i in cells:
			var dy := absi(occupied.x - cell.x)
			var da := absi(occupied.y - cell.y)
			da = mini(da, SURFACE_SECTORS - da)
			var distance := dy * dy + da * da
			var candidate := float(cells[occupied])
			if distance < nearest or (distance == nearest and candidate > radius):
				nearest = distance
				radius = candidate
				source_cell = occupied
		if nearest == 2147483647:
			return {"valid": false, "inside": false, "reason": "no occupied surface bins"}
	var clearance := float(sample["radius"]) - radius
	return {"valid": true, "inside": clearance < -SURFACE_MARGIN, "clearance": clearance,
		"radius": radius, "cell": cell, "source_cell": source_cell, "fallback": fallback}


func _skin_points(fixture: Dictionary, mats: Array, ids: PackedInt32Array) -> PackedVector3Array:
	var ctx: Dictionary = fixture["ctx"]
	var arrays: Array = fixture["arrays"]
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var per := int(bones.size() / positions.size())
	var mesh_node: MeshInstance3D = ctx["mesh_node"]
	var root: Node3D = fixture["root"]
	var to_body := root.global_transform.affine_inverse() * mesh_node.global_transform
	var points := PackedVector3Array()
	for id in ids:
		var point := Vector3.ZERO
		for influence in per:
			var at := id * per + influence
			if weights[at] > 0.0:
				point += (mats[bones[at]] as Transform3D) * positions[id] * weights[at]
		points.append(to_body * point)
	return points


func _center(points: PackedVector3Array) -> Vector3:
	var center := Vector3.ZERO
	for point in points:
		center += point
	return center / float(points.size())


func _snapshot(fixture: Dictionary, clip: String, phase: float, frozen: bool = false, layer_override: Dictionary = {}) -> Dictionary:
	var ctx: Dictionary = fixture["ctx"]
	var entry := _entry(clip)
	if frozen or not layer_override.is_empty():
		BodyBake._pose_at(ctx, "", 0.0, {})
		var source_layer: Dictionary = layer_override if not layer_override.is_empty() else PROTECTED_HAND_LAYERS[clip]
		BodyBake.apply_layer(ctx["body"], source_layer, phase, float(ctx.get("sink_scale", 1.0)))
	else:
		BodyBake.pose(ctx, entry[1], entry[4], phase, clip)
	var mats: Array = BodyBake._skin_frame(ctx)
	var out := {}
	for group: String in fixture["groups"]:
		out[group] = _skin_points(fixture, mats, fixture["groups"][group])
	out["left_center"] = _center(out["left"])
	out["right_center"] = _center(out["right"])
	var joints := {}
	for bone: String in ["hips", "spine", "chest", "neck", "head", "upper_arm.R", "forearm.R", "hand.R", "upper_arm.L", "forearm.L", "hand.L", "thigh.L", "shin.L", "foot.L", "thigh.R", "shin.R", "foot.R"]:
		joints[bone] = _joint(ctx, fixture["root"], bone)
	out["joints"] = joints
	if not frozen and layer_override.is_empty():
		var status: Dictionary = ctx.get("hand_targets", {}).get(clip, {}).duplicate(true)
		if status.has("selected_target"):
			var root: Node3D = fixture["root"]
			var skeleton: Skeleton3D = ctx["body"]
			status["selected_root"] = root.global_transform.affine_inverse() * skeleton.global_transform * (status["selected_target"] as Vector3)
		out["reach"] = status
	return out


func _guard_gap(a: Dictionary, b: Dictionary) -> float:
	var greatest := 0.0
	for group: String in ["left", "right", "torso"]:
		var aa: PackedVector3Array = a[group]
		var bb: PackedVector3Array = b[group]
		for id in aa.size():
			greatest = maxf(greatest, aa[id].distance_to(bb[id]))
	for bone: String in a["joints"]:
		greatest = maxf(greatest, (a["joints"][bone] as Vector3).distance_to(b["joints"][bone]))
	return greatest


func _check_follow(fixture: Dictionary, clip: String, sample: Dictionary, frame: String, phase: float) -> void:
	var hand: Vector3 = sample["right_center"]
	var hips: Vector3 = sample["joints"]["hips"]
	var height := hand.y - hips.y
	var side := hand.x - hips.x
	var reach: Dictionary = sample.get("reach", {})
	var label := "rig=%s clip=%s frame=%s phase=%.8f height=%.8f side=%.8f m" % [fixture["name"], clip, frame, phase, height, side]
	print("ONEHAND_FOLLOW " + label)
	assert_true(bool(reach.get("ok", false)) and reach.has("selected_root"), label + " selected target exists")
	assert_false(bool(reach.get("clipped", false)), label + " no clipped solve")
	if not reach.has("selected_root"):
		return
	var error := hand.distance_to(reach["selected_root"])
	assert_true(height <= 0.0, label + " hand at or below hips")
	assert_true(error <= 0.01, "%s selected target error %.8f m <= 0.01" % [label, error])
	assert_gt(side * (1.0 if clip == "p_swing_one" else -1.0), 0.0, label + " arrival side")


## 이 변경의 관통 책임 구간. 보호 자세·감김의 기존 실패는 별도 관찰값으로 남긴다.
static func surface_is_in_followthrough(clip: String, phase: float) -> bool:
	if not is_finite(phase) or clip not in ["p_swing_one", "p_swing_back"]:
		return false
	var band: Dictionary = BodyBake.LAYERS[clip]["hand_targets"][0]["separation"]
	return phase >= float(band["complete"]) and phase <= float(band["return_start"])


static func minimum_free_arm_clearance(sample: Dictionary) -> float:
	var surface := torso_surface(sample["torso"], sample["joints"]["hips"], sample["joints"]["chest"])
	if not bool(surface["valid"]):
		return NAN
	var worst := INF
	for point: Vector3 in sample["free_arm"]:
		var check := surface_clearance(surface, point)
		if not bool(check["valid"]):
			return NAN
		worst = minf(worst, float(check["clearance"]))
	return worst


func _check_clip(fixture: Dictionary, clip: String, ready: Dictionary) -> void:
	var hit := 0.45 if clip == "p_swing_one" else 0.33
	var target_spec: Dictionary = BodyBake.LAYERS[clip]["hand_targets"][0]
	var separation: Dictionary = target_spec["separation"]
	var follow := lerpf(hit, GUARD, (0.62 - 0.45) / (GUARD - 0.45))
	var frames: Array[Dictionary] = []
	var inside_frames := 0
	var outside_scope_frames := 0
	for frame in FRAMES:
		var phase := float(frame) / float(FRAMES - 1)
		var sample := _snapshot(fixture, clip, phase)
		frames.append(sample)
		var label := "rig=%s clip=%s frame=%d phase=%.8f" % [fixture["name"], clip, frame, phase]
		if phase >= float(separation["complete"]) and phase <= float(separation["return_start"]):
			var gap := (sample["left_center"] as Vector3).distance_to(sample["right_center"])
			assert_true(gap >= MIN_HAND_GAP, "%s hand gap %.8f m >= %.2f" % [label, gap, MIN_HAND_GAP])
		var surface := torso_surface(sample["torso"], sample["joints"]["hips"], sample["joints"]["chest"])
		assert_true(bool(surface["valid"]), label + " valid torso surface")
		if not bool(surface["valid"]):
			continue
		var worst := INF
		var worst_id := -1
		var worst_cell := Vector2i.ZERO
		var worst_source := Vector2i.ZERO
		var fallback_count := 0
		var arm: PackedVector3Array = sample["free_arm"]
		for id in arm.size():
			var clearance := surface_clearance(surface, arm[id])
			assert_true(bool(clearance["valid"]), "%s valid arm vertex=%d" % [label, fixture["groups"]["free_arm"][id]])
			if not bool(clearance["valid"]):
				continue
			if bool(clearance["fallback"]):
				fallback_count += 1
			if float(clearance["clearance"]) < worst:
				worst = float(clearance["clearance"])
				worst_id = int(fixture["groups"]["free_arm"][id])
				worst_cell = clearance["cell"]
				worst_source = clearance["source_cell"]
		var in_scope := surface_is_in_followthrough(clip, phase)
		var baseline := minimum_free_arm_clearance(_snapshot(fixture, clip, phase, false, SURFACE_BASELINE_LAYERS[clip]))
		assert_true(is_finite(baseline), label + " finite original surface baseline")
		if worst < -SURFACE_MARGIN:
			if in_scope:
				inside_frames += 1
			else:
				outside_scope_frames += 1
		print("ONEHAND_SURFACE %s in_scope=%s bins=%d fallback_vertices=%d baseline=%.8f worst=%.8f m" % [label, str(in_scope).to_lower(), (surface["cells"] as Dictionary).size(), fallback_count, baseline, worst])
		if in_scope or baseline >= -SURFACE_MARGIN:
			assert_true(worst >= -SURFACE_MARGIN, "%s free arm vertex=%d surface clearance=%.8f m margin=%.3f bin=%s source_bin=%s" % [
				label, worst_id, worst, SURFACE_MARGIN, worst_cell, worst_source])
		elif is_finite(baseline):
			assert_true(worst >= baseline - 0.000001, "%s existing out-of-scope penetration must not worsen baseline=%.8f current=%.8f" % [label, baseline, worst])
		if frame >= 18:
			var gap := _guard_gap(sample, ready)
			assert_lt(gap, GUARD_TOLERANCE, "%s guard gap %.8f m < 0.01" % [label, gap])
	assert_eq(inside_frames, 0, "rig=%s clip=%s torso penetration frames=%d" % [fixture["name"], clip, inside_frames])
	print("ONEHAND_SURFACE_SCOPE rig=%s clip=%s in_scope_bad=%d outside_scope_bad=%d" % [fixture["name"], clip, inside_frames, outside_scope_frames])
	for phase: float in [0.0, 0.7826, GUARD]:
		var gap := _guard_gap(_snapshot(fixture, clip, phase), ready)
		assert_lt(gap, GUARD_TOLERANCE, "rig=%s clip=%s guard phase=%.8f gap=%.8f m" % [fixture["name"], clip, phase, gap])
	for phase: float in [follow, 0.62]:
		var at := int(roundf(phase * float(FRAMES - 1)))
		_check_follow(fixture, clip, frames[at], str(at), float(at) / float(FRAMES - 1))
		_check_follow(fixture, clip, _snapshot(fixture, clip, phase), "key", phase)
	_check_sag(fixture, clip, frames, hit)
	_report_sampling(fixture, clip, frames, hit)
	_check_protected_hand_poses(fixture, clip, hit)
	_report_hand_reach(fixture, clip, target_spec)
	_check_separation_bands(fixture, clip, target_spec, hit, frames)
	_check_handle_projection(fixture, clip, frames, separation)


func _sample_hand(frames: Array[Dictionary], phase: float) -> Vector3:
	var cursor := clampf(phase, 0.0, 1.0) * float(FRAMES - 1)
	var low := int(floorf(cursor))
	var high := mini(low + 1, FRAMES - 1)
	return (frames[low]["right_center"] as Vector3).lerp(frames[high]["right_center"], cursor - float(low))


func _check_sag(fixture: Dictionary, clip: String, frames: Array[Dictionary], hit: float) -> void:
	var end := (GUARD - hit) / (1.0 - hit)
	var previous := Vector3.ZERO
	var still := 0.0
	var longest := 0.0
	var travel := 0.0
	var worst_at := 0.0
	# 0.90초 회복의 0.153초부터 0.30초를 0.01초 간격으로 검사한다.
	for sample in 31:
		var elapsed := 0.17 * 0.90 + float(sample) * 0.01
		var progress := Pose.recovery_phase(elapsed, 0.90, 0.35, end)
		var phase := lerpf(hit, 1.0, progress)
		var hand := _sample_hand(frames, phase)
		if sample > 0:
			var moved := hand.distance_to(previous)
			travel += moved
			still = still + 0.01 if moved / 0.01 < STILL_SPEED else 0.0
			if still > longest:
				longest = still
				worst_at = phase
		previous = hand
	var label := "rig=%s clip=%s phase=%.8f frame=%.4f sag travel=%.8f m longest still=%.5f s speed<%.3f m/s" % [
		fixture["name"], clip, worst_at, worst_at * 23.0, travel, longest, STILL_SPEED]
	print("ONEHAND_SAG " + label)
	assert_gt(travel, 0.0, label + " travel > 0")
	assert_true(longest <= MAX_STILL_SECONDS + 0.00000001, label + " still <= 0.15 s")


func _report_sampling(fixture: Dictionary, clip: String, frames: Array[Dictionary], hit: float) -> void:
	for first_phase: float in [0.52, 0.55, 0.62, 0.65, 0.70, 0.74]:
		var phase := lerpf(hit, GUARD, (first_phase - 0.45) / (GUARD - 0.45))
		var exact := _snapshot(fixture, clip, phase)
		var cursor := phase * 23.0
		var low := int(floorf(cursor))
		var high := mini(low + 1, FRAMES - 1)
		var error := (exact["right_center"] as Vector3).distance_to(_sample_hand(frames, phase))
		print("ONEHAND_SAMPLE rig=%s clip=%s phase=%.8f frames=%d/%d hand_error=%.8f m" % [
			fixture["name"], clip, phase, low, high, error])


func _check_rig(rig_name: String) -> void:
	assert_not_null(_motion, "F-INPUT-MISSING motion for " + rig_name)
	if _motion == null:
		return
	var path := _source_dir.path_join("rig").path_join(rig_name + ".glb")
	assert_true(FileAccess.file_exists(path), "F-INPUT-MISSING " + path)
	if not FileAccess.file_exists(path):
		return
	var started := Time.get_ticks_msec()
	var root := _source_scene(path)
	if root == null:
		return
	add_child(root)
	var entries: Array = [_entry(CLIPS[0]), _entry(CLIPS[1]), _entry("p_ready_one")]
	var ctx := BodyBake.prepare(root, _motion, entries, [])
	assert_false(ctx.is_empty(), "F-SOURCE-CONTEXT " + rig_name)
	if ctx.is_empty():
		root.free()
		return
	# 몸 굽기와 같은 골반 비례 처짐을 쓴다.
	ctx["sink_scale"] = BodyBake._sink_scale(root, ctx["body"])
	var arrays: Array = (ctx["mesh_node"] as MeshInstance3D).mesh.surface_get_arrays(0)
	var fixture := {"name": rig_name, "root": root, "ctx": ctx, "arrays": arrays}
	fixture["groups"] = _vertex_groups(ctx, arrays)
	var valid := true
	for group: String in fixture["groups"]:
		var ids: PackedInt32Array = fixture["groups"][group]
		assert_false(ids.is_empty(), "%s missing vertex group %s" % [rig_name, group])
		valid = valid and not ids.is_empty()
	if not valid:
		root.free()
		return
	var ready := _snapshot(fixture, "p_ready_one", 0.0)
	for frame in FRAMES:
		var phase := float(frame) / float(FRAMES)
		var gap := _guard_gap(_snapshot(fixture, "p_ready_one", phase), ready)
		assert_lt(gap, GUARD_TOLERANCE, "%s p_ready_one frame=%d phase=%.8f gap=%.8f m" % [rig_name, frame, phase, gap])
	for clip: String in CLIPS:
		var entry := _entry(clip)
		assert_eq(int(entry[2]), FRAMES, rig_name + " " + clip + " full frame count")
		_check_clip(fixture, clip, ready)
	var pose_failures: Array = ctx.get("fit_failures", [])
	if not pose_failures.is_empty():
		print("ONEHAND_POSE_FAILURE rig=%s failures=%s" % [rig_name, pose_failures])
	assert_true(pose_failures.is_empty(), rig_name + " pose failures")
	_checked.append(rig_name)
	root.free()
	print("ONEHAND_RIG rig=%s seconds=%.3f" % [rig_name, float(Time.get_ticks_msec() - started) / 1000.0])


func test_source_rig_list_has_fourteen_distinct_bodies() -> void:
	var names := {}
	for rig: String in SOURCE_RIGS:
		names[rig] = true
	assert_eq(names.size(), 14, "fourteen distinct source rigs")


## The protected-key dip is pinned: only the first swing, at 60 fps, on 24 frames, between
## 10/23 and 11/23, and no deeper than 25.83 mm. Everything just outside is refused.
func test_protected_dip_is_only_the_first_swing_between_its_protected_frames() -> void:
	var inside_from := 0.4475  # the 60 fps samples bake 4 measured: 0.4475 -> 0.4753
	var inside_to := 0.47529094
	assert_true(_protected_dip_allowed("p_swing_one", 60, FRAMES, inside_from, inside_to, 0.025826810), "railman_old, the deepest measured")
	assert_true(_protected_dip_allowed("p_swing_one", 60, FRAMES, PROTECTED_DIP_FROM, PROTECTED_DIP_TO, PROTECTED_DIP_MAX), "the closed edges")
	assert_false(_protected_dip_allowed("p_swing_one", 60, FRAMES, inside_from, inside_to, PROTECTED_DIP_MAX + 0.000001), "deeper")
	assert_false(_protected_dip_allowed("p_swing_back", 60, FRAMES, inside_from, inside_to, 0.001), "the back swing")
	assert_false(_protected_dip_allowed("p_swing_one", 30, FRAMES, inside_from, inside_to, 0.001), "30 fps")
	assert_false(_protected_dip_allowed("p_swing_one", 60, FRAMES - 1, inside_from, inside_to, 0.001), "another frame count")
	assert_false(_protected_dip_allowed("p_swing_one", 60, FRAMES, PROTECTED_DIP_FROM - 0.000001, inside_to, 0.001), "starting before 10/23")
	assert_false(_protected_dip_allowed("p_swing_one", 60, FRAMES, inside_from, PROTECTED_DIP_TO + 0.000001, 0.001), "ending after 11/23")
	assert_false(_protected_dip_allowed("p_swing_one", 60, FRAMES, inside_to, inside_from, 0.001), "a step that runs backwards")
	assert_false(_protected_dip_allowed("p_swing_one", 60, FRAMES, 0.5407, 0.5592, 0.001), "a later opening phase")


func test_driver_onehand_keys() -> void:
	_check_rig("driver")


func test_duffel_b1v2_onehand_keys() -> void:
	_check_rig("duffel_b1v2")


func test_fitter_onehand_keys() -> void:
	_check_rig("fitter")


func test_guard_onehand_keys() -> void:
	_check_rig("guard")


func test_guard_f_onehand_keys() -> void:
	_check_rig("guard_f")


func test_hunter_f_onehand_keys() -> void:
	_check_rig("hunter_f")


func test_lumberjack_onehand_keys() -> void:
	_check_rig("lumberjack")


func test_medic_onehand_keys() -> void:
	_check_rig("medic")


func test_overalls_onehand_keys() -> void:
	_check_rig("overalls")


func test_railman_old_onehand_keys() -> void:
	_check_rig("railman_old")


func test_seamstress_onehand_keys() -> void:
	_check_rig("seamstress")


func test_sheepskin_onehand_keys() -> void:
	_check_rig("sheepskin")


func test_stoker_onehand_keys() -> void:
	_check_rig("stoker")


func test_woodsman_onehand_keys() -> void:
	_check_rig("woodsman")


## 대조 전용 문맥이며 기존 실제 리그 시험의 흐름은 바꾸지 않는다.
func _comparison_fixture(rig_name: String) -> Dictionary:
	assert_not_null(_motion, "F-INPUT-MISSING motion for " + rig_name)
	if _motion == null:
		return {}
	var path := _source_dir.path_join("rig").path_join(rig_name + ".glb")
	assert_true(FileAccess.file_exists(path), "F-INPUT-MISSING " + path)
	if not FileAccess.file_exists(path):
		return {}
	var root := _source_scene(path)
	assert_not_null(root, "F-SOURCE-SCENE " + rig_name)
	if root == null:
		return {}
	add_child(root)
	var ctx := BodyBake.prepare(root, _motion, [_entry("p_swing_one")], [])
	assert_false(ctx.is_empty(), "F-SOURCE-CONTEXT " + rig_name)
	if ctx.is_empty():
		root.free()
		return {}
	ctx["sink_scale"] = BodyBake._sink_scale(root, ctx["body"])
	var arrays: Array = (ctx["mesh_node"] as MeshInstance3D).mesh.surface_get_arrays(0)
	var fixture := {"name": rig_name, "root": root, "ctx": ctx, "arrays": arrays}
	fixture["groups"] = _vertex_groups(ctx, arrays)
	var valid := true
	for group: String in fixture["groups"]:
		var ids: PackedInt32Array = fixture["groups"][group]
		assert_false(ids.is_empty(), "%s missing comparison group %s" % [rig_name, group])
		valid = valid and not ids.is_empty()
	if not valid:
		root.free()
		return {}
	fixture["old_radius"] = _legacy_torso_radius(fixture)
	var old_radius: float = fixture["old_radius"]
	assert_true(is_finite(old_radius) and old_radius > 0.0, rig_name + " valid old radius")
	if not is_finite(old_radius) or old_radius <= 0.0:
		root.free()
		return {}
	return fixture


## 옛 반지름을 rest 몸통의 골반~가슴 범위에서 그대로 재구성한다.
func _legacy_torso_radius(fixture: Dictionary) -> float:
	var ctx: Dictionary = fixture["ctx"]
	var root: Node3D = fixture["root"]
	var body: Skeleton3D = ctx["body"]
	var to_body := root.global_transform.affine_inverse() * body.global_transform
	var hips := to_body * body.get_bone_global_rest(BodyBake._bone(body, "hips")).origin
	var chest := to_body * body.get_bone_global_rest(BodyBake._bone(body, "chest")).origin
	var axis := chest - hips
	if axis.length_squared() < 0.00000001:
		return NAN
	var mesh_node: MeshInstance3D = ctx["mesh_node"]
	var to_mesh_body := root.global_transform.affine_inverse() * mesh_node.global_transform
	var arrays: Array = fixture["arrays"]
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var radius := 0.0
	for id: int in fixture["groups"]["torso"]:
		var point := to_mesh_body * vertices[id]
		var share := (point - hips).dot(axis) / axis.length_squared()
		if share >= 0.0 and share <= 1.0:
			radius = maxf(radius, point.distance_to(hips + axis * share))
	return radius


func _clearance_pair(surface: Dictionary, points: PackedVector3Array, hips: Vector3, chest: Vector3, old_radius: float) -> Dictionary:
	var result := {"valid": false, "old": INF, "new": INF, "new_index": -1, "inside": 0}
	var axis := chest - hips
	if not bool(surface.get("valid", false)) or points.is_empty() or axis.length_squared() < 0.00000001:
		return result
	for id in points.size():
		var point := points[id]
		var share := clampf((point - hips).dot(axis) / axis.length_squared(), 0.0, 1.0)
		result["old"] = minf(float(result["old"]), point.distance_to(hips + axis * share) - old_radius)
		var check := surface_clearance(surface, point)
		if not bool(check["valid"]):
			return result
		if bool(check["inside"]):
			result["inside"] = int(result["inside"]) + 1
		if float(check["clearance"]) < float(result["new"]):
			result["new"] = check["clearance"]
			result["new_index"] = id
	result["valid"] = is_finite(float(result["old"])) and is_finite(float(result["new"]))
	return result


## 높이·둘레 방향을 유지한다. 대조의 절대 여유는 얇은 몸에서도 1 cm 문턱을 넘는다.
static func _pushed_arm(surface: Dictionary, arm: PackedVector3Array, fraction: float, clearance: float = NAN) -> Dictionary:
	var points := PackedVector3Array()
	var count := 0
	var max_radius := 0.0
	for point in arm:
		var check := surface_clearance(surface, point)
		if not bool(check["valid"]):
			return {"valid": false, "points": points, "count": count, "max_radius": max_radius}
		var radius: float = check["radius"]
		if radius <= 0.0:
			points.append(point)
			continue
		var coords := _surface_coordinates(surface, point)
		var height: float = coords["height"]
		var axis_point: Vector3 = (surface["origin"] as Vector3) + (surface["axis"] as Vector3) * height
		var radial := point - axis_point
		var direction: Vector3 = radial.normalized() if radial.length_squared() > 0.00000001 else surface["forward"]
		var target_radius := radius * fraction if is_nan(clearance) else maxf(0.0, radius + clearance)
		points.append(axis_point + direction * target_radius)
		count += 1
		max_radius = maxf(max_radius, radius)
	return {"valid": count > 0, "points": points, "count": count, "max_radius": max_radius}


func test_free_arm_pushed_into_chest_is_caught() -> void:
	for rig_name: String in ["driver", "duffel_b1v2"]:
		var fixture := _comparison_fixture(rig_name)
		if fixture.is_empty():
			continue
		for phase: float in [0.0, 0.30]:
			var sample := _snapshot(fixture, "p_swing_one", phase)
			var hips: Vector3 = sample["joints"]["hips"]
			var chest: Vector3 = sample["joints"]["chest"]
			var surface := torso_surface(sample["torso"], hips, chest)
			assert_true(bool(surface["valid"]), "%s phase %.8f comparison surface" % [rig_name, phase])
			if not bool(surface["valid"]):
				continue
			var arm: PackedVector3Array = sample["free_arm"]
			var untouched := arm.duplicate()
			var original := _clearance_pair(surface, arm, hips, chest, fixture["old_radius"])
			print("ONEHAND_CLEARANCE_CMP rig=%s phase=%.8f case=original old=%.8f new=%.8f" % [
				rig_name, phase, original["old"], original["new"]])
			var label := "%s phase %.8f original old=%.8f new=%.8f m" % [rig_name, phase, original["old"], original["new"]]
			assert_true(bool(original["valid"]), label + " finite comparison")
			# 원래 자세가 이미 뚫을 수 있으므로 양성 대조는 표면 밖 15 mm 복사본이다.
			var outside := _pushed_arm(surface, arm, 1.0, 0.015)
			var outside_check := _clearance_pair(surface, outside["points"], hips, chest, fixture["old_radius"])
			assert_true(bool(outside["valid"]) and bool(outside_check["valid"]), label + " outside control exists")
			assert_eq(int(outside_check["inside"]), 0, label + " outside control is clear")
			assert_true(float(outside_check["new"]) >= -SURFACE_MARGIN, label + " outside control >= -0.01")
			print("ONEHAND_CLEARANCE_CMP rig=%s phase=%.8f case=outside15mm old=%.8f new=%.8f" % [
				rig_name, phase, outside_check["old"], outside_check["new"]])
			for row: Array in [["push50", 0.50, NAN], ["push80", 0.80, NAN], ["inside15mm", 1.0, -0.015]]:
				var pushed := _pushed_arm(surface, arm, float(row[1]), float(row[2]))
				var moved: PackedVector3Array = pushed["points"]
				var comparison := _clearance_pair(surface, moved, hips, chest, fixture["old_radius"])
				print("ONEHAND_CLEARANCE_CMP rig=%s phase=%.8f case=%s old=%.8f new=%.8f" % [
					rig_name, phase, row[0], comparison["old"], comparison["new"]])
				var detail := "%s phase %.8f case=%s vertices=%d max_radius=%.8f old=%.8f new=%.8f m" % [
					rig_name, phase, row[0], pushed["count"], pushed["max_radius"], comparison["old"], comparison["new"]]
				assert_true(bool(pushed["valid"]) and moved.size() == arm.size(), detail + " pushed copy exists")
				assert_true(bool(comparison["valid"]), detail + " finite comparison")
				assert_gt(int(comparison["inside"]), 0, detail + " detects penetration")
				assert_lt(float(comparison["new"]), -SURFACE_MARGIN, detail + " clearance < -0.01")
			assert_eq(arm, untouched, "%s phase %.8f source points unchanged" % [rig_name, phase])
		(fixture["root"] as Node3D).free()


func _section_points(surface: Dictionary, points: PackedVector3Array, height: float) -> Array:
	var result: Array = []
	var axis_point: Vector3 = (surface["origin"] as Vector3) + (surface["axis"] as Vector3) * height
	for point in points:
		var coordinates := _surface_coordinates(surface, point)
		if absf(float(coordinates["height"]) - height) <= SURFACE_HEIGHT:
			var delta := point - axis_point
			result.append([delta.dot(surface["left"]), delta.dot(surface["forward"])])
	return result


func _emit_surface_section(fixture: Dictionary, phase: float) -> void:
	var sample := _snapshot(fixture, "p_swing_one", phase)
	var hips: Vector3 = sample["joints"]["hips"]
	var chest: Vector3 = sample["joints"]["chest"]
	var surface := torso_surface(sample["torso"], hips, chest)
	assert_true(bool(surface["valid"]), "%s phase %.8f section surface" % [fixture["name"], phase])
	if not bool(surface["valid"]):
		return
	var arm: PackedVector3Array = sample["free_arm"]
	var nearest := _clearance_pair(surface, arm, hips, chest, fixture["old_radius"])
	assert_true(bool(nearest["valid"]), "%s phase %.8f finite section clearance" % [fixture["name"], phase])
	if not bool(nearest["valid"]):
		return
	var index := int(nearest["new_index"])
	assert_true(index >= 0 and index < arm.size(), "%s phase %.8f nearest arm vertex" % [fixture["name"], phase])
	if index < 0 or index >= arm.size():
		return
	var coordinates := _surface_coordinates(surface, arm[index])
	var height: float = coordinates["height"]
	var axis_point: Vector3 = (surface["origin"] as Vector3) + (surface["axis"] as Vector3) * height
	var radii: Array[float] = []
	for sector in SURFACE_SECTORS:
		var angle := TAU * float(sector) / float(SURFACE_SECTORS)
		var radial: Vector3 = (surface["left"] as Vector3) * sin(angle) + (surface["forward"] as Vector3) * cos(angle)
		var check := surface_clearance(surface, axis_point + radial)
		assert_true(bool(check["valid"]), "%s section sector %d" % [fixture["name"], sector])
		if not bool(check["valid"]):
			return
		radii.append(float(check["radius"]))
	var section := {
		"rig": fixture["name"], "phase": phase, "axis_height": height,
		"torso": _section_points(surface, sample["torso"], height),
		"arm": _section_points(surface, arm, height),
		"surface_radius_by_sector": radii, "old_radius": fixture["old_radius"],
	}
	assert_eq(radii.size(), SURFACE_SECTORS, fixture["name"] + " twelve surface sectors")
	assert_false((section["arm"] as Array).is_empty(), fixture["name"] + " nearest arm in section")
	print("ONEHAND_SECTION " + JSON.stringify(section, "", false))


func test_free_arm_surface_sections_are_reported() -> void:
	for row: Array in [["driver", 0.0], ["duffel_b1v2", 6.0 / 23.0], ["guard", 7.0 / 23.0]]:
		var fixture := _comparison_fixture(row[0])
		if fixture.is_empty():
			continue
		_emit_surface_section(fixture, float(row[1]))
		(fixture["root"] as Node3D).free()


func _report_hand_reach(fixture: Dictionary, clip: String, spec: Dictionary) -> void:
	var sample := _snapshot(fixture, clip, float(spec["follow"]))
	var status: Dictionary = sample.get("reach", {})
	var reached: float = (sample["right_center"] as Vector3).y - (sample["joints"]["hips"] as Vector3).y
	var target_y := NAN
	if status.has("selected_root"):
		target_y = (status["selected_root"] as Vector3).y - (sample["joints"]["hips"] as Vector3).y
	print("ONEHAND_REACH rig=%s clip=%s target_y=%.8f reached_y=%.8f error_from_pref=%.8f clipped=%s valid=%s reason=%s" % [
		fixture["name"], clip, target_y, reached, absf(reached - float(spec["preferred_y"])),
		str(bool(status.get("clipped", false))).to_lower(), str(bool(status.get("ok", false))).to_lower(), status.get("reason", "")])
	assert_true(bool(status.get("ok", false)), "%s %s valid reach %s" % [fixture["name"], clip, status])
	assert_false(bool(status.get("clipped", false)), "%s %s clipped final goal" % [fixture["name"], clip])


func _check_protected_hand_poses(fixture: Dictionary, clip: String, hit: float) -> void:
	var before_hit := floorf(hit * float(FRAMES - 1)) / float(FRAMES - 1)
	var after_hit := ceilf(hit * float(FRAMES - 1)) / float(FRAMES - 1)
	for phase: float in [0.0, before_hit, hit, after_hit, 0.7826, GUARD]:
		var expected: Dictionary
		if phase == before_hit or phase == after_hit:
			expected = _snapshot(fixture, clip, phase, false, SURFACE_BASELINE_LAYERS[clip])
		else:
			expected = _snapshot(fixture, clip, phase, true)
		var actual := _snapshot(fixture, clip, phase)
		var gap := _guard_gap(actual, expected)
		assert_lt(gap, 0.01, "%s %s protected phase %.8f original gap %.8f m" % [fixture["name"], clip, phase, gap])
		var surface := torso_surface(actual["torso"], actual["joints"]["hips"], actual["joints"]["chest"])
		var worst := INF
		var inside := 0
		var valid := bool(surface["valid"])
		if valid:
			for point: Vector3 in actual["free_arm"]:
				var clearance := surface_clearance(surface, point)
				if not bool(clearance["valid"]):
					valid = false
					break
				worst = minf(worst, float(clearance["clearance"]))
				inside += int(bool(clearance["inside"]))
		print("ONEHAND_PROTECTED_SURFACE rig=%s clip=%s phase=%.8f pose_gap=%.8f min_clearance=%.8f inside=%d valid=%s" % [
			fixture["name"], clip, phase, gap, worst if valid else NAN, inside, str(valid).to_lower()])


func _recover_time(phase: float, hit: float) -> float:
	var low := 0.0
	var high := 0.90
	var end := (GUARD - hit) / (1.0 - hit)
	for iteration in 32:
		var middle := (low + high) * 0.5
		var at := lerpf(hit, 1.0, Pose.recovery_phase(middle, 0.90, 0.35, end))
		if at < phase:
			low = middle
		else:
			high = middle
	return (low + high) * 0.5


func _phase_in_recovery(time: float, hit: float) -> float:
	return lerpf(hit, 1.0, Pose.recovery_phase(time, 0.90, 0.35, (GUARD - hit) / (1.0 - hit)))


func _sample_separation(frames: Array[Dictionary], phase: float) -> Dictionary:
	var at := clampf(phase, 0.0, 1.0) * float(frames.size() - 1)
	var first := mini(int(floorf(at)), frames.size() - 1)
	var second := mini(first + 1, frames.size() - 1)
	var weight := at - float(first)
	var result := {"joints": {}}
	for hand: String in ["left_center", "right_center"]:
		result[hand] = (frames[first][hand] as Vector3).lerp(frames[second][hand], weight)
	for joint: String in frames[first]["joints"]:
		result["joints"][joint] = (frames[first]["joints"][joint] as Vector3).lerp(frames[second]["joints"][joint], weight)
	return result


## Whether a step of the opening band whose gap fell by `drop` lies inside the one dip the
## protected first-swing keys leave (see PROTECTED_DIP_*). Both samples must sit between
## the two protected frames.
static func _protected_dip_allowed(clip: String, fps: int, frame_count: int, previous_phase: float, phase: float, drop: float) -> bool:
	return (clip == PROTECTED_DIP_CLIP and fps == PROTECTED_DIP_FPS and frame_count == FRAMES
		and previous_phase >= PROTECTED_DIP_FROM and phase <= PROTECTED_DIP_TO and previous_phase <= phase
		and drop <= PROTECTED_DIP_MAX)


func _check_separation_bands(fixture: Dictionary, clip: String, spec: Dictionary, hit: float, frames: Array[Dictionary]) -> void:
	var band: Dictionary = spec["separation"]
	var begin := _recover_time(float(band["start"]), hit)
	var complete := _recover_time(float(band["complete"]), hit)
	var returning := _recover_time(float(band["return_start"]), hit)
	var guard := _recover_time(float(band["guard"]), hit)
	assert_almost_eq(float(band["start"]), hit, 0.000001, "the opening band begins at contact")
	assert_true(returning - complete >= 0.15, "%s %s declared separated duration %.6f s" % [fixture["name"], clip, returning - complete])
	var boundaries: Array[float] = [hit, float(band["complete"]), float(band["return_start"]), float(band["guard"])]
	for key: Array in spec["weight"][1]:
		if float(key[0]) >= hit and not boundaries.has(float(key[0])):
			boundaries.append(float(key[0]))
	for phase: float in boundaries:
		var before := _snapshot(fixture, clip, maxf(0.0, phase - 0.000001))
		var after := _snapshot(fixture, clip, minf(1.0, phase + 0.000001))
		for hand: String in ["left_center", "right_center"]:
			assert_lt((after[hand] as Vector3).distance_to(before[hand]), 0.001,
				"%s %s %s continuous boundary %.8f" % [fixture["name"], clip, hand, phase])
	for fps: int in [30, 60]:
		var maximum_speed := 0.0
		for interval: Array in [["opening", begin, complete], ["return", returning, guard]]:
			var start := _sample_separation(frames, _phase_in_recovery(interval[1], hit))
			var finish := _sample_separation(frames, _phase_in_recovery(interval[2], hit))
			var start_gap := (start["left_center"] as Vector3).distance_to(start["right_center"])
			var end_gap := (finish["left_center"] as Vector3).distance_to(finish["right_center"])
			if interval[0] == "opening":
				assert_true(end_gap >= start_gap, "%s %s opening ends wider" % [fixture["name"], clip])
			var previous := start
			var previous_gap := start_gap
			var previous_time: float = interval[1]
			var previous_phase := _phase_in_recovery(float(interval[1]), hit)
			for step in range(1, int(ceil((float(interval[2]) - float(interval[1])) * float(fps))) + 1):
				var time := minf(float(interval[2]), float(interval[1]) + float(step) / float(fps))
				var phase := _phase_in_recovery(time, hit)
				var sample := _sample_separation(frames, phase)
				var gap := (sample["left_center"] as Vector3).distance_to(sample["right_center"])
				var label := "%s %s %s fps=%d phase=%.8f gap=%.8f previous=%.8f" % [fixture["name"], clip, interval[0], fps, phase, gap, previous_gap]
				if interval[0] == "opening":
					var drop := previous_gap - gap
					if drop > 0.00001 and _protected_dip_allowed(clip, fps, frames.size(), previous_phase, phase, drop):
						print("ONEHAND_PROTECTED_DIP rig=%s clip=%s fps=%d phase=%.8f previous_phase=%.8f drop=%.8f m" % [
							fixture["name"], clip, fps, phase, previous_phase, drop])
					else:
						assert_true(gap - previous_gap >= -0.00001, label + " monotonic separation")
				for hand: String in ["left_center", "right_center"]:
					var travel := (sample[hand] as Vector3).distance_to(previous[hand])
					assert_true(is_finite(travel), "%s %s finite frame travel" % [label, hand])
					if time > previous_time:
						maximum_speed = maxf(maximum_speed, travel / (time - previous_time))
				previous = sample
				previous_gap = gap
				previous_time = time
				previous_phase = phase
		var held := 0.0
		var longest := 0.0
		var was_valid := false
		var previous_time := complete
		for step in int(ceil((returning - complete) * float(fps))) + 1:
			var time := minf(returning, complete + float(step) / float(fps))
			var phase := _phase_in_recovery(time, hit)
			var sample := _sample_separation(frames, phase)
			var left: Vector3 = sample["left_center"]
			var hips: Vector3 = sample["joints"]["hips"]
			var chest: Vector3 = sample["joints"]["chest"]
			var gap := left.distance_to(sample["right_center"])
			var valid := gap >= 0.25 and left.x - hips.x > 0.10 and left.y < chest.y
			assert_true(gap >= 0.25, "%s %s stable fps=%d phase=%.8f gap=%.8f" % [fixture["name"], clip, fps, phase, gap])
			held = held + time - previous_time if valid and was_valid else 0.0
			longest = maxf(longest, held)
			was_valid = valid
			previous_time = time
		print("ONEHAND_BALANCE rig=%s clip=%s fps=%d duration=%.8f side_hold=%.8f max_speed=%.8f" % [fixture["name"], clip, fps, returning - complete, longest, maximum_speed])
		assert_true(longest >= 0.15, "%s %s free-hand side balance %.6f s >= 0.15" % [fixture["name"], clip, longest])


## 무기 원본의 축 방향 폭이 손잡이 폭의 세 배를 넘는 첫 구간까지를 검사한다.
func _measure_handle_span() -> Vector2:
	var root := _source_scene(ProjectSettings.globalize_path("res://models/weapons/axe.glb"))
	assert_not_null(root, "axe source for handle projection")
	if root == null:
		return Vector2(NAN, NAN)
	add_child(root)
	var bins := {}
	var low := INF
	var grip_radius := 0.0
	var meshes: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.push_front(root)
	for found: Node in meshes:
		var mesh_node := found as MeshInstance3D
		var to_root := root.global_transform.affine_inverse() * mesh_node.global_transform
		for surface in mesh_node.mesh.get_surface_count():
			var positions: PackedVector3Array = mesh_node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex in positions:
				var point := to_root * vertex
				var radius := Vector2(point.x, point.y).length()
				var bin := int(floorf(point.z / 0.02))
				bins[bin] = maxf(float(bins.get(bin, 0.0)), radius)
				low = minf(low, point.z)
				if point.z >= 0.0 and point.z <= 0.06:
					grip_radius = maxf(grip_radius, radius)
	var head := INF
	for bin: int in bins:
		if float(bin) * 0.02 >= 0.06 and float(bins[bin]) > grip_radius * 3.0:
			head = minf(head, float(bin) * 0.02)
	root.free()
	assert_true(grip_radius > 0.0 and is_finite(head) and low < 0.0, "weapon data defines a handle span")
	print("ONEHAND_HANDLE_DATA lower=%.8f upper=%.8f length=%.8f pitch=%.1f yaw=%.1f" % [low, head, head - low, CAMERA_PITCH, CAMERA_YAW])
	return Vector2(low, head)


func _camera_point(point: Vector3, yaw: float) -> Vector2:
	var pitch := deg_to_rad(CAMERA_PITCH)
	var camera_yaw := deg_to_rad(CAMERA_YAW)
	var back := Vector3(sin(camera_yaw) * cos(pitch), sin(pitch), cos(camera_yaw) * cos(pitch))
	var right := Vector3.UP.cross(back).normalized()
	var up := back.cross(right).normalized()
	var rotated := Basis(Vector3.UP, yaw) * point
	return Vector2(rotated.dot(right), rotated.dot(up))


func _hull_overlaps_handle(hull: PackedVector2Array, a: Vector2, b: Vector2) -> bool:
	if hull.size() < 3:
		return false
	if Geometry2D.is_point_in_polygon(a, hull) or Geometry2D.is_point_in_polygon(b, hull):
		return true
	for edge in hull.size():
		if Geometry2D.segment_intersects_segment(a, b, hull[edge], hull[(edge + 1) % hull.size()]) != null:
			return true
	return false


func _check_handle_projection(fixture: Dictionary, clip: String, frames: Array[Dictionary], band: Dictionary) -> void:
	assert_true(is_finite(_handle_span.x) and is_finite(_handle_span.y), "valid weapon handle data")
	if not is_finite(_handle_span.x) or not is_finite(_handle_span.y):
		return
	for facing in 8:
		var count := 0
		var stable_count := 0
		var failed_frames: Array[int] = []
		var yaw := deg_to_rad(float(facing) * 45.0)
		for frame in frames.size():
			var phase := float(frame) / float(FRAMES - 1)
			var sample: Dictionary = frames[frame]
			var hand: Vector3 = sample["right_center"]
			var elbow: Vector3 = sample["joints"]["forearm.R"]
			var grip := Visual.wrist_target(Visual.grip_target(hand, elbow), Visual.wrist_weight(clip, phase))
			var projected := PackedVector2Array()
			for point: Vector3 in sample["left"]:
				projected.append(_camera_point(point, yaw))
			var hull := Geometry2D.convex_hull(projected)
			assert_true(hull.size() >= 3, "%s %s frame=%d facing=%d nonempty hand hull" % [fixture["name"], clip, frame, facing])
			var a := _camera_point(hand + grip.z * _handle_span.x, yaw)
			var b := _camera_point(hand + grip.z * _handle_span.y, yaw)
			if _hull_overlaps_handle(hull, a, b):
				count += 1
				if phase >= float(band["complete"]) and phase <= float(band["return_start"]):
					stable_count += 1
					failed_frames.append(frame)
		print("ONEHAND_HANDLE_OVERLAP rig=%s clip=%s facing=%d all=%d stable=%d frames=%s" % [fixture["name"], clip, facing * 45, count, stable_count, failed_frames])
		assert_eq(stable_count, 0, "%s %s facing=%d stable handle overlap %s" % [fixture["name"], clip, facing * 45, failed_frames])


func test_handle_projection_catches_edges_and_containment() -> void:
	var hull := PackedVector2Array([Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)])
	assert_true(_hull_overlaps_handle(hull, Vector2(-2, 0), Vector2(2, 0)))
	assert_true(_hull_overlaps_handle(hull, Vector2.ZERO, Vector2(0.5, 0.5)))
	assert_false(_hull_overlaps_handle(hull, Vector2(2, 2), Vector2(3, 3)))
