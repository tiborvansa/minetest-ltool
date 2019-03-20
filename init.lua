local S = minetest.get_translator("ltool")
local N = function(s) return s end
local F = minetest.formspec_escape

ltool = {}

ltool.VERSION = {}
ltool.VERSION.MAJOR = 1
ltool.VERSION.MINOR = 5
ltool.VERSION.PATCH = 0
ltool.VERSION.STRING = ltool.VERSION.MAJOR .. "." .. ltool.VERSION.MINOR .. "." .. ltool.VERSION.PATCH

ltool.playerinfos = {}
ltool.default_edit_fields = {
	axiom="",
	rules_a="",
	rules_b="",
	rules_c="",
	rules_d="",
	trunk="mapgen_tree",
	leaves="mapgen_leaves",
	leaves2="mapgen_jungleleaves",
	leaves2_chance="0",
	fruit="mapgen_apple",
	fruit_chance="0",
	angle="45",
	iterations="2",
	random_level="0",
	trunk_type="single",
	thin_branches="true",
	name = "",
}

local mod_select_item = minetest.get_modpath("select_item") ~= nil

local sapling_base_name = S("L-System Tree Sapling")
local sapling_format_string = N("L-System Tree Sapling (@1)")

local place_tree = function(pos)
	-- Place tree
	local meta = minetest.get_meta(pos)
	local treedef = minetest.deserialize(meta:get_string("treedef"))
	minetest.remove_node(pos)
	minetest.spawn_tree(pos, treedef)
end

--[[ This registers the sapling for planting the trees ]]
minetest.register_node("ltool:sapling", {
	description = sapling_base_name,
	_doc_items_longdesc = S("This artificial sapling does not come from nature and contains the genome of a genetically engineered L-system tree. Every sapling of this kind is unique. Who knows what might grow from it when you plant it?"),
	_doc_items_usagehelp = S("Place the sapling on any floor and wait 5 seconds for the tree to appear. If you have the “lplant” privilege, you can grow it instantly by using it. If you hold down the sneak key while placing it, you will keep a copy of the sapling in your inventory.").."\n"..S("To create your own saplings, you need to have the “lplant” privilege and pick a tree from the L-System Tree Utility (accessed with the server command “treeform”)."),
	drawtype = "plantlike",
	tiles = { "ltool_sapling.png" },
	inventory_image = "ltool_sapling.png",
	selection_box = {
		type = "fixed",
		fixed = { -10/32, -0.5, -10/32, 10/32, 12/32, 10/32 },
	},
	wield_image = "ltool_sapling.png",
	paramtype = "light",
	paramtype2= "wallmounted",
	walkable = false,
	groups = { dig_immediate = 3, not_in_creative_inventory=1, },
	drop = "",
	sunlight_propagates = true,
	is_ground_content = false,
	after_place_node = function(pos, placer, itemstack, pointed_thing)
		-- Transfer metadata and start timer
		local nodemeta = minetest.get_meta(pos)
		local itemmeta = itemstack:get_meta()
		local itemtreedef = itemmeta:get_string("treedef")

		-- Legacy support for saplings with legacy metadata
		if itemtreedef == nil or itemtreedef == "" then
			itemtreedef = itemstack:get_metadata()
			if itemtreedef == nil or itemtreedef == "" then
				return nil
			end
		end
		nodemeta:set_string("treedef", itemtreedef)
		local timer = minetest.get_node_timer(pos)
		timer:start(5)
		if placer:get_player_control().sneak == true then
			return true
		else
			return nil
		end
	end,
	-- Insta-grow when sapling got rightclicked
	on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
		if minetest.get_player_privs(clicker:get_player_name()).lplant then
			place_tree(pos)
		end
	end,
	-- Grow after timer elapsed
	on_timer = place_tree,
	can_dig = function(pos, player)
		return minetest.get_player_privs(player:get_player_name()).lplant
	end,
})

minetest.register_craftitem("ltool:tool", {
	description = S("L-System Tree Utility"),
	_doc_items_longdesc = S("This gadget allows the aspiring genetic engineer to invent and change L-system trees, create L-system tree saplings and look at the inventions from other players. L-system trees are trees and tree-like strucures which are built by a set of (possibly recursive) production rules."),
	_doc_items_usagehelp = S("Punch to open the L-System editor. A tabbed form will open. To edit and create trees, you need the “ledit” privilege, to make saplings, you need “lplant”. Detailed usage help can be found in that menu. You can also access the same editor with the server command “treeform”."),
	inventory_image = "ltool_tool.png",
	wield_image = "ltool_tool.png",
	on_use = function(itemstack, user, pointed_thing)
		ltool.show_treeform(user:get_player_name())
	end,
})

--[[ Register privileges ]]
minetest.register_privilege("ledit", {
	description = S("Can add, edit, rename and delete own L-system tree definitions of the ltool mod"),
	give_to_singleplayer = false,
})
minetest.register_privilege("lplant", {
	description = S("Can place L-system trees and get L-system tree saplings of the ltool mod"),
	give_to_singleplayer = false,
})

--[[ Load previously saved data from file or initialize an empty tree table ]]
do
	local filepath = minetest.get_worldpath().."/ltool.mt"
	local file = io.open(filepath, "r")
	if(file) then
		local string = file:read()
		io.close(file)
		if(string ~= nil) then
			local savetable = minetest.deserialize(string)
			if(savetable ~= nil) then
				ltool.trees = savetable.trees
				ltool.next_tree_id = savetable.next_tree_id
				ltool.number_of_trees = savetable.number_of_trees
				minetest.log("action", "[ltool] Tree data loaded from "..filepath..".")
			else
				minetest.log("error", "[ltool] Failed to load tree data from "..filepath..".")
			end
		else
			minetest.log("error", "[ltool] Failed to load tree data from "..filepath..".")
		end
	else
		--[[ table of all trees ]]
		ltool.trees = {}
		--[[ helper variables to ensure unique IDs ]]
		ltool.number_of_trees = 0
		ltool.next_tree_id = 1
	end
end

--[[ Adds a tree to the tree table.
	name: The tree’s name.
	author: The author’s / owners’ name
	treedef: The full tree definition, see lua_api.txt

	returns the tree ID of the new tree
]]
function ltool.add_tree(name, author, treedef)
	local id = ltool.next_tree_id
	ltool.trees[id] = {name = name, author = author, treedef = treedef}
	ltool.next_tree_id = ltool.next_tree_id + 1
	ltool.number_of_trees = ltool.number_of_trees + 1
	return id
end

--[[ Removes a tree from the database
	tree_id: ID of the tree to be removed

	returns nil
]]
function ltool.remove_tree(tree_id)
	ltool.trees[tree_id] = nil
	ltool.number_of_trees = ltool.number_of_trees - 1
	for k,v in pairs(ltool.playerinfos) do
		if(v.dbsel ~= nil) then
			if(v.dbsel > ltool.number_of_trees) then
				v.dbsel = ltool.number_of_trees
			end
			if(v.dbsel < 1) then
				v.dbsel = 1
			end
		end
	end
end

--[[ Renames a tree in the database
	tree_id: ID of the tree to be renamed
	new_name: The name of the tree

	returns nil
]]
function ltool.rename_tree(tree_id, new_name)
	ltool.trees[tree_id].name = new_name
end

--[[ Copies a tree in the database
	tree_id: ID of the tree to be copied

	returns: the ID of the copy on success;
	         false on failure (tree does not exist)
]]
function ltool.copy_tree(tree_id)
	local tree = ltool.trees[tree_id]
	if(tree == nil) then
		return false
	end
	return ltool.add_tree(tree.name, tree.author, tree.treedef)
end

--[[ Gives a L-system tree sapling to a player
	treedef: L-system tree definition table of tree the sapling will grow
	seed: Seed of the tree (optional; can be nil)
	playername: name of the player to which
	ignore_priv: if true, player’s lplant privilige is not checked (optional argument; default: false)
	treename: Descriptive name of the tree for the item description (optional, is ignored if nil or empty string)

	returns:
		true on success
		false, 1 if privilege is not sufficient
		false, 2 if player’s inventory is full
]]
function ltool.give_sapling(treedef, seed, player_name, ignore_priv, treename)
	local privs = minetest.get_player_privs(player_name)
	if(ignore_priv == nil) then ignore_priv = false end
	if(ignore_priv == false and privs.lplant ~= true) then
		return false, 1
	end

	local sapling = ItemStack("ltool:sapling")
	local player = minetest.get_player_by_name(player_name)
	treedef.seed = seed
	local smeta = sapling:get_meta()
	smeta:set_string("treedef", minetest.serialize(treedef))
	if treename and treename ~= "" then
		smeta:set_string("description", S(sapling_format_string, treename))
	end
	treedef.seed = nil
	local leftover = player:get_inventory():add_item("main", sapling)
	if(not leftover:is_empty()) then
		return false, 2
	else
		return true
	end
end

--[[ Plants a tree as the specified position
	tree_id: ID of tree to be planted
	pos: Position of tree, in format {x=?, y=?, z=?}
	seed: Optional seed for randomness, equal seed makes equal trees

	returns false on failure, nil otherwise
]]
function ltool.plant_tree(tree_id, pos, seed)
	local tree = ltool.trees[tree_id]
	if(tree==nil) then
		return false
	end
	local treedef
	if seed ~= nil then
		treedef = table.copy(tree.treedef)
		treedef.seed = seed
	else
		treedef = tree.treedef
	end
	minetest.spawn_tree(pos, treedef)
end

--[[ Tries to return a tree data structure for a given tree_id

	tree_id: ID of tee to be returned

	returns false on failure, a tree otherwise
]]
function ltool.get_tree(tree_id)
	local tree = ltool.trees[tree_id]
	if(tree==nil) then
		return false
	end
	return tree
end


ltool.seed = os.time()


--[=[ Here come the functions to build the main formspec.
They do not build the entire formspec ]=]

ltool.formspec_size = "size[12,9]"

--[[ This is a part of the main formspec: Tab header ]]
function ltool.formspec_header(index)
	return "tabheader[0,0;ltool_tab;"..F(S("Edit"))..","..F(S("Database"))..","..F(S("Plant"))..","..F(S("Help"))..";"..tostring(index)..";true;false]"
end

--[[ This creates the edit tab of the formspec
	fields: A template used to fill the default values of the formspec. ]]
function ltool.tab_edit(fields, has_ledit_priv, has_lplant_priv)
	if(fields==nil) then
		fields = ltool.default_edit_fields
	end
	local s = function(input)
		local ret
		if(input==nil) then
			ret = ""
		else
			ret = F(tostring(input))
		end
		return ret
	end

	-- Show save/clear buttons depending on privs
	local leditbuttons
	if has_ledit_priv then
		leditbuttons = "button[0,8.7;4,0;edit_save;"..F(S("Save tree to database")).."]"..
		"button[4,8.7;4,0;edit_clear;"..F(S("Reset fields")).."]"
		if has_lplant_priv then
			leditbuttons = leditbuttons .. "button[8,8.7;4,0;edit_sapling;"..F(S("Generate sapling")).."]"
		end
	else
		leditbuttons = "label[0,8.3;"..F(S("Read-only mode. You need the “ledit” privilege to save trees to the database.")).."]"
	end

	local nlength = "3"
	local fields_select_item = ""
	if mod_select_item then
		nlength = "2.6"
		fields_select_item = ""..
		"button[2.4,5.7;0.5,0;edit_trunk;"..F(S(">")).."]"..
		"button[5.4,5.7;0.5,0;edit_leaves;"..F(S(">")).."]"..
		"button[8.4,5.7;0.5,0;edit_leaves2;"..F(S(">")).."]"..
		"button[11.4,5.7;0.5,0;edit_fruit;"..F(S(">")).."]"..
		"tooltip[edit_trunk;"..F(S("Select node")).."]"..
		"tooltip[edit_leaves;"..F(S("Select node")).."]"..
		"tooltip[edit_leaves2;"..F(S("Select node")).."]"..
		"tooltip[edit_fruit;"..F(S("Select node")).."]"
	end

	local trunk_type_mapping_reverse = {
		["single"] = 1,
		["double"] = 2,
		["crossed"] = 3,
	}
	local trunk_type_idx
	if fields.trunk_type then
		trunk_type_idx = trunk_type_mapping_reverse[fields.trunk_type]
	else
		trunk_type_idx = 1
	end

	return ""..
	"field[0.2,1;11,0;axiom;"..F(S("Axiom"))..";"..s(fields.axiom).."]"..
	"button[11,0.7;1,0;edit_axiom;"..F(S("+")).."]"..
	"tooltip[edit_axiom;"..F(S("Opens larger text field for Axiom")).."]"..
	"field[0.2,2;11,0;rules_a;"..F(S("Rules set A"))..";"..s(fields.rules_a).."]"..
	"button[11,1.7;1,0;edit_rules_a;"..F(S("+")).."]"..
	"tooltip[edit_rules_a;"..F(S("Opens larger text field for Rules set A")).."]"..
	"field[0.2,3;11,0;rules_b;"..F(S("Rules set B"))..";"..s(fields.rules_b).."]"..
	"button[11,2.7;1,0;edit_rules_b;"..F(S("+")).."]"..
	"tooltip[edit_rules_b;"..F(S("Opens larger text field for Rules set B")).."]"..
	"field[0.2,4;11,0;rules_c;"..F(S("Rules set C"))..";"..s(fields.rules_c).."]"..
	"button[11,3.7;1,0;edit_rules_c;"..F(S("+")).."]"..
	"tooltip[edit_rules_c;"..F(S("Opens larger text field for Rules set C")).."]"..
	"field[0.2,5;11,0;rules_d;"..F(S("Rules set D"))..";"..s(fields.rules_d).."]"..
	"button[11,4.7;1,0;edit_rules_d;"..F(S("+")).."]"..
	"tooltip[edit_rules_d;"..F(S("Opens larger text field for Rules set D")).."]"..

	"field[0.2,6;"..nlength..",0;trunk;"..F(S("Trunk node"))..";"..s(fields.trunk).."]"..
	"field[3.2,6;"..nlength..",0;leaves;"..F(S("Leaves node"))..";"..s(fields.leaves).."]"..
	"field[6.2,6;"..nlength..",0;leaves2;"..F(S("Secondary leaves node"))..";"..s(fields.leaves2).."]"..
	"field[9.2,6;"..nlength..",0;fruit;"..F(S("Fruit node"))..";"..s(fields.fruit).."]"..
	fields_select_item..

	"label[-0.075,5.95;"..F(S("Trunk type")).."]"..
	"dropdown[-0.075,6.35;3;trunk_type;single,double,crossed;"..trunk_type_mapping_reverse[fields.trunk_type].."]"..
	"tooltip[trunk_type;"..F(S("Tree trunk type. Possible values:\n- \"single\": trunk of size 1×1\n- \"double\": trunk of size 2×2\n- \"crossed\": trunk in cross shape (3×3).")).."]"..
	"checkbox[2.9,6.2;thin_branches;"..F(S("Thin branches"))..";"..s(fields.thin_branches).."]"..
	"tooltip[thin_branches;"..F(S("If enabled, all branches are just 1 node wide, otherwise, branches can be larger.")).."]"..
	"field[6.2,7;3,0;leaves2_chance;"..F(S("Secondary leaves chance (%)"))..";"..s(fields.leaves2_chance).."]"..
	"tooltip[leaves2_chance;"..F(S("Chance (in percent) to replace a leaves node by a secondary leaves node")).."]"..
	"field[9.2,7;3,0;fruit_chance;"..F(S("Fruit chance (%)"))..";"..s(fields.fruit_chance).."]"..
	"tooltip[fruit_chance;"..F(S("Chance (in percent) to replace a leaves node by a fruit node.")).."]"..

	"field[0.2,8;3,0;iterations;"..F(S("Iterations"))..";"..s(fields.iterations).."]"..
	"tooltip[iterations;"..F(S("Maximum number of iterations, usually between 2 and 5.")).."]"..
	"field[3.2,8;3,0;random_level;"..F(S("Randomness level"))..";"..s(fields.random_level).."]"..
	"tooltip[random_level;"..F(S("Factor to lower number of iterations, usually between 0 and 3.")).."]"..
	"field[6.2,8;3,0;angle;"..F(S("Angle (°)"))..";"..s(fields.angle).."]"..
	"field[9.2,8;3,0;name;"..F(S("Name"))..";"..s(fields.name).."]"..
	"tooltip[name;"..F(S("Descriptive name for this tree, only used for convenience.")).."]"..
	leditbuttons
end

--[[ This creates the database tab of the formspec.
	index: Selected index of the textlist
	playername: To whom the formspec is shown
]]
function ltool.tab_database(index, playername)
	local treestr, tree_ids = ltool.build_tree_textlist(index, playername)
	if(treestr ~= nil) then
		local indexstr
		if(index == nil) then
			indexstr = ""
		else
			indexstr = tostring(index)
		end
		ltool.playerinfos[playername].treeform.database.textlist = tree_ids

		local leditbuttons, lplantbuttons
		if minetest.get_player_privs(playername).ledit then
			leditbuttons = "button[3,7.5;3,1;database_rename;"..F(S("Rename tree")).."]"..
			"button[6,7.5;3,1;database_delete;"..F(S("Delete tree")).."]"
		else
			leditbuttons = "label[0.2,7.2;"..F(S("Read-only mode. You need the “ledit” privilege to edit trees.")).."]"
		end
		if minetest.get_player_privs(playername).lplant then
			lplantbuttons = "button[0,8.5;3,1;sapling;"..F(S("Generate sapling")).."]"
		else
			lplantbuttons = ""
		end

		return ""..
		"textlist[0,0;11,7;treelist;"..treestr..";"..tostring(index)..";false]"..
		lplantbuttons..
		leditbuttons..
		"button[3,8.5;3,1;database_copy;"..F(S("Copy tree to editor")).."]"..
		"button[6,8.5;3,1;database_update;"..F(F("Reload database")).."]"
	else
		return "label[0,0;"..F(S("The tree database is empty.")).."]"..
		"button[6.5,8.5;3,1;database_update;"..F(F("Reload database")).."]"
	end
end

--[[ This creates the "Plant" tab part of the main formspec ]]
function ltool.tab_plant(tree, fields, has_lplant_priv)
	if(tree ~= nil) then
		local seltree = "label[0,-0.2;"..F(S("Selected tree: @1", tree.name)).."]"
		if not has_lplant_priv then
			return seltree..
			"label[0,0.3;"..F(S("Planting of trees is not allowed. You need to have the “lplant” privilege.")).."]"
		end
		if(fields==nil) then
			fields = {}
		end
		local s = function(i)
			if(i==nil) then return ""
			else return tostring(F(i))
			end
		end
		local seed
		if(fields.seed == nil) then
			seed = tostring(ltool.seed)
		else
			seed = fields.seed
		end
		local dropdownindex
		if(fields.plantmode == F(S("Absolute coordinates"))) then
			dropdownindex = 1
		elseif(fields.plantmode == F(S("Relative coordinates"))) then
			dropdownindex = 2
		elseif(fields.plantmode == F(S("Distance in viewing direction"))) then
			dropdownindex = 3
		else
			dropdownindex = 1
		end

		return ""..
		seltree..
		"dropdown[-0.1,0.5;5;plantmode;"..F(S("Absolute coordinates"))..","..F(S("Relative coordinates"))..","..F(S("Distance in viewing direction"))..";"..dropdownindex.."]"..
--[[ NOTE: This tooltip does not work for the dropdown list in 0.4.10,
but it is added anyways in case this gets fixed in later Minetest versions. ]]
		"tooltip[plantmode;"..
		F(S("- \"Absolute coordinates\": Fields \"x\", \"y\" and \"z\" specify the absolute world coordinates where to plant the tree")).."\n"..
		F(S("- \"Relative coordinates\": Fields \"x\", \"y\" and \"z\" specify the relative position from your position")).."\n"..
		F(S("- \"Distance in viewing direction\": Plant tree relative from your position in the direction you look to, at the specified distance"))..
		"]"..
		"field[0.2,-2;6,10;x;"..F(S("x"))..";"..s(fields.x).."]"..
		"tooltip[x;"..F(S("Field is only used by absolute and relative coordinates.")).."]"..
		"field[0.2,-1;6,10;y;"..F(S("y"))..";"..s(fields.y).."]"..
		"tooltip[y;"..F(S("Field is only used by absolute and relative coordinates.")).."]"..
		"field[0.2,0;6,10;z;"..F(S("z"))..";"..s(fields.z).."]"..
		"tooltip[z;"..F(S("Field is only used by absolute and relative coordinates.")).."]"..
		"field[0.2,1;6,10;distance;"..F(S("Distance"))..";"..s(fields.distance).."]"..
		"tooltip[distance;"..F(S("This field is used to specify the distance (in node lengths) from your position\nin the viewing direction. It is ignored if you use coordinates.")).."]"..
		"field[0.2,2;6,10;seed;"..F(S("Randomness seed"))..";"..seed.."]"..
		"tooltip[seed;"..F(S("A number used for the random number generators. Identical randomness seeds will produce identical trees. This field is optional.")).."]"..
		"button[3.5,8;3,1;plant_plant;"..F(S("Plant tree")).."]"..
		"tooltip[plant_plant;"..F(S("Immediately place the tree at the specified position")).."]"..
		"button[6.5,8;3,1;sapling;"..F(S("Generate sapling")).."]"..
		"tooltip[sapling;"..F(S("This gives you an item which you can place manually in the world later")).."]"
	else
		local notreestr = F(S("No tree in database selected or database is empty."))
		if has_lplant_priv then
			return "label[0,0;"..notreestr.."]"
		else
			return "label[0,0;"..notreestr.."\n"..F(S("You are not allowed to plant trees anyway as you don't have the “lplant” privilege.")).."]"
		end
	end
end


--[[ This creates the cheat sheet tab ]]
function ltool.tab_cheat_sheet()
	return ""..
	"tablecolumns[text;text]"..
	"tableoptions[background=#000000;highlight=#000000;border=false]"..
	"table[-0.15,0.75;12,8;cheat_sheet;"..
	F(S("Symbol"))..","..F(S("Action"))..","..
	"G,"..F(S("Move forward one unit with the pen up"))..","..
	"F,"..F(S("Move forward one unit with the pen down drawing trunks and branches"))..","..
	"f,"..F(S("Move forward one unit with the pen down drawing leaves"))..","..
	"T,"..F(S("Move forward one unit with the pen down drawing trunks"))..","..
	"R,"..F(S("Move forward one unit with the pen down placing fruit"))..","..
	"A,"..F(S("Replace with rules set A"))..","..
	"B,"..F(S("Replace with rules set B"))..","..
	"C,"..F(S("Replace with rules set C"))..","..
	"D,"..F(S("Replace with rules set D"))..","..
	"a,"..F(S("Replace with rules set A, chance 90%"))..","..
	"b,"..F(S("Replace with rules set B, chance 80%"))..","..
	"c,"..F(S("Replace with rules set C, chance 70%"))..","..
	"d,"..F(S("Replace with rules set D, chance 60%"))..","..
	"+,"..F(S("Yaw the turtle right by angle parameter"))..","..
	"-,"..F(S("Yaw the turtle left by angle parameter"))..","..
	"&,"..F(S("Pitch the turtle down by angle parameter"))..","..
	"^,"..F(S("Pitch the turtle up by angle parameter"))..","..
	"/,"..F(S("Roll the turtle to the right by angle parameter"))..","..
	"*,"..F(S("Roll the turtle to the left by angle parameter"))..","..
	"\\[,"..F(S("Save in stack current state info"))..","..
	"\\],"..F(S("Recover from stack state info")).."]"
end

-- TODO: Make help translatable
function ltool.tab_help_intro()
	return ""..
	"tablecolumns[text]"..
	"tableoptions[background=#000000;highlight=#000000;border=false]"..
	"table[-0.15,0.75;12,7;help_intro;"..
	F(S("You are using the L-System Tree Utility, version @1.", ltool.VERSION.STRING))..","..
	","..
	"The purpose of this utility is to aid with the creation of L-system trees.,"..
	"You can create\\, save\\, manage and plant L-system trees.,"..
	"All trees are saved into <world path>/ltool.mt on server shutdown.,"..
	"It assumes you already understand the concept of L-systems\\;,"..
	"this utility is mainly aimed towards modders and nerds.,"..
	","..
	"The usual workflow goes like this:,"..
	","..
	"1. Create a new tree in the \"Edit\" tab and save it,"..
	"2. Select it in the database,"..
	"3. Plant it,"..
	","..
	"To help you get started\\, you can create an example tree for the \"Edit\" tab,"..
	"by pressing this button:]"..
	"button[4,8;4,1;create_template;Create template]"
end

function ltool.tab_help_edit()
	return ""..
	"tablecolumns[text]"..
	"tableoptions[background=#000000;highlight=#000000;border=false]"..
	"table[-0.15,0.75;12,8;help_edit;"..
	"To create a L-system tree\\, switch to the \"Edit\" tab.,"..
	"When you are done\\, hit \"Save tree to database\". The tree will be stored in,"..
	"the database. The \"Reset fields\" button resets the input fields to defaults.,"..
	"To understand the meaning of the fields\\, read the introduction to L-systems.,"..
	"All trees must have an unique name. You are notified in case there is a name,"..
	"clash. If the name clash is with one of your own trees\\, you can choose to,"..
	"replace it.]"
end

function ltool.tab_help_database()
	return ""..
	"tablecolumns[text]"..
	"tableoptions[background=#000000;highlight=#000000;border=false]"..
	"table[-0.15,0.75;12,8;help_database;"..
	"The database contains a list of all created trees among all players.,"..
	"Each tree has an \"owner\". This kind of ownership is limited:,"..
	"The owner may rename\\, change and delete their own trees\\,,"..
	"everyone else is prevented from doing that. But all trees can be,"..
	"copied freely by everyone\\;,"..
	"To do so\\, simply hit \"Copy tree to editor\"\\, change the name and hit,"..
	"\"Save tree to database\". If you like someone else's tree definition\\,,"..
	"it is recommended to make a copy for yourself\\, since the original owner,"..
	"can at any time choose to delete or edit the tree. The trees which you \"own\","..
	"are written in a yellow font\\, all other trees in a white font.,"..
	"In order to plant a tree\\, you have to select a tree in the database first.]"
end

function ltool.tab_help_plant()
	return ""..
	"tablecolumns[text]"..
	"tableoptions[background=#000000;highlight=#000000;border=false]"..
	"table[-0.15,0.75;12,8;help_plant;"..
	"To plant a tree from a previously created tree definition\\, first select,"..
	"it in the database\\, then open the \"Plant\" tab.,"..
	"In this tab\\, you can directly place the tree or request a sapling.,"..
	"If you choose to directly place the tree\\, you can either specify absolute,"..
	"or relative coordinates or specify that the tree should be planted in your,"..
	"viewing direction. Absolute coordinates are the world coordinates as specified,"..
	"by the \"x\"\\, \"y\"\\, and \"z\" fields. Relative coordinates are relative,"..
	"to your position and use the same fields. When you choose to plant the tree,"..
	"based on your viewing direction\\, the tree will be planted at a distance,"..
	"specified by the field \"distance\" away from you in the direction you look to.,"..
	"When using coordinates\\, the \"distance\" field is ignored\\, when using,"..
	"direction\\, the coordinate fields are ignored.,"..
	","..
	"You can also use the “lplant” server command to plant trees.,"..
	","..
	"If you got a sapling\\, you can place it practically anywhere you like to.,"..
	"After placing it\\, the sapling will be replaced by the L-system tree after,"..
	"5 seconds\\, unless it was destroyed in the meantime.,"..
	"All requested saplings are independent from the moment they are created.,"..
	"The sapling will still work\\, even if the original tree definiton has been,"..
	"deleted.]"
end

function ltool.tab_help(index)
	local formspec = "tabheader[0.1,1;ltool_help_tab;"..F(S("Introduction"))..","..F(S("Creating Trees"))..","..F(S("Managing Trees"))..","..F(S("Planting Trees"))..","..F(S("Cheat Sheet"))..";"..tostring(index)..";true;false]"
	if(index==1) then
		formspec = formspec .. ltool.tab_help_intro()
	elseif(index==2) then
		formspec = formspec .. ltool.tab_help_edit()
	elseif(index==3) then
		formspec = formspec .. ltool.tab_help_database()
	elseif(index==4) then
		formspec = formspec .. ltool.tab_help_plant()
	elseif(index==5) then
		formspec = formspec .. ltool.tab_cheat_sheet()
	end

	return formspec
end

function ltool.formspec_editplus(fragment)
	local formspec = ""..
	"size[12,8]"..
	"textarea[0.2,0.5;12,3;"..fragment.."]"..
	"label[0,3.625;"..F(S("Draw:")).."]"..
	"button[2,3.5;1,1;editplus_c_G;G]"..
	"tooltip[editplus_c_G;"..F(S("Move forward one unit with the pen up")).."]"..
	"button[3,3.5;1,1;editplus_c_F;F]"..
	"tooltip[editplus_c_F;"..F(S("Move forward one unit with the pen down drawing trunks and branches")).."]"..
	"button[4,3.5;1,1;editplus_c_f;f]"..
	"tooltip[editplus_c_f;"..F(S("Move forward one unit with the pen down drawing leaves")).."]"..
	"button[5,3.5;1,1;editplus_c_T;T]"..
	"tooltip[editplus_c_T;"..F(S("Move forward one unit with the pen down drawing trunks")).."]"..
	"button[6,3.5;1,1;editplus_c_R;R]"..
	"tooltip[editplus_c_R;"..F(S("Move forward one unit with the pen down placing fruit")).."]"..

	"label[0,4.625;"..F(S("Rules:")).."]"..
	"button[2,4.5;1,1;editplus_c_A;A]"..
	"tooltip[editplus_c_A;"..F(S("Replace with rules set A")).."]"..
	"button[3,4.5;1,1;editplus_c_B;B]"..
	"tooltip[editplus_c_B;"..F(S("Replace with rules set B")).."]"..
	"button[4,4.5;1,1;editplus_c_C;C]"..
	"tooltip[editplus_c_C;"..F(S("Replace with rules set C")).."]"..
	"button[5,4.5;1,1;editplus_c_D;D]"..
	"tooltip[editplus_c_D;"..F(S("Replace with rules set D")).."]"..
	"button[6.5,4.5;1,1;editplus_c_a;a]"..
	"tooltip[editplus_c_a;"..F(S("Replace with rules set A, chance 90%")).."]"..
	"button[7.5,4.5;1,1;editplus_c_b;b]"..
	"tooltip[editplus_c_b;"..F(S("Replace with rules set B, chance 80%")).."]"..
	"button[8.5,4.5;1,1;editplus_c_c;c]"..
	"tooltip[editplus_c_c;"..F(S("Replace with rules set C, chance 70%")).."]"..
	"button[9.5,4.5;1,1;editplus_c_d;d]"..
	"tooltip[editplus_c_d;"..F(S("Replace with rules set D, chance 60%")).."]"..

	"label[0,5.625;"..F(S("Rotate:")).."]"..
	"button[3,5.5;1,1;editplus_c_+;+]"..
	"tooltip[editplus_c_+;"..F(S("Yaw the turtle right by the value specified in \"Angle\"")).."]"..
	"button[2,5.5;1,1;editplus_c_-;-]"..
	"tooltip[editplus_c_-;"..F(S("Yaw the turtle left by the value specified in \"Angle\"")).."]"..
	"button[4.5,5.5;1,1;editplus_c_&;&]"..
	"tooltip[editplus_c_&;"..F(S("Pitch the turtle down by the value specified in \"Angle\"")).."]"..
	"button[5.5,5.5;1,1;editplus_c_^;^]"..
	"tooltip[editplus_c_^;"..F(S("Pitch the turtle up by the value specified in \"Angle\"")).."]"..
	"button[8,5.5;1,1;editplus_c_/;/]"..
	"tooltip[editplus_c_/;"..F(S("Roll the turtle to the right by the value specified in \"Angle\"")).."]"..
	"button[7,5.5;1,1;editplus_c_*;*]"..
	"tooltip[editplus_c_*;"..F(S("Roll the turtle to the left by the value specified in \"Angle\"")).."]"..

	"label[0,6.625;"..F(S("Stack:")).."]"..
	"button[2,6.5;1,1;editplus_c_P;\\[]"..
	"tooltip[editplus_c_P;"..F(S("Save current state info into stack")).."]"..
	"button[3,6.5;1,1;editplus_c_p;\\]]"..
	"tooltip[editplus_c_p;"..F(S("Recover from current stack state info")).."]"..

	"button[2.5,7.5;3,1;editplus_save;"..F(S("Save")).."]"..
	"button[5.5,7.5;3,1;editplus_cancel;"..F(S("Cancel")).."]"

	return formspec
end

--[[ creates the content of a textlist which contains all trees.
	index: Selected entry
	playername: To which the main formspec is shown to. Used for highlighting owned trees

	returns (string to be used in the text list, table of tree IDs)
]]
function ltool.build_tree_textlist(index, playername)
	local string = ""
	local colorstring
	if(ltool.number_of_trees == 0) then
		return nil
	end
	local tree_ids = ltool.get_tree_ids()
	for i=1,#tree_ids do
		local tree_id = tree_ids[i]
		local tree = ltool.trees[tree_id]
		if(tree.author == playername) then
			colorstring = "#FFFF00"
		else
			colorstring = ""
		end
		string = string .. colorstring .. tostring(tree_id) .. ": " .. F(tree.name)
		if(i~=#tree_ids) then
			string = string .. ","
		end
	end
	return string, tree_ids
end

--[=[ Here come functions which show formspecs to players ]=]

--[[ Shows the main tree form to the given player, starting with the "Edit" tab ]]
function ltool.show_treeform(playername)
	local privs = minetest.get_player_privs(playername)
	local formspec = ltool.formspec_size..ltool.formspec_header(1)..ltool.tab_edit(ltool.playerinfos[playername].treeform.edit.fields, privs.ledit, privs.lplant)
	minetest.show_formspec(playername, "ltool:treeform_edit", formspec)
end

--[[ spawns a simple dialog formspec to a player ]]
function ltool.show_dialog(playername, formname, message)
	local formspec = "size[12,2;]label[0,0.2;"..message.."]"..
	"button[4.5,1.5;3,1;okay;"..F(S("OK")).."]"
	minetest.show_formspec(playername, formname, formspec)

end


--[=[ End of formspec-relatec functions ]=]

--[[ This function does a lot of parameter checks and returns (tree, tree_name) on success.
	If ANY parameter check fails, the whole function fails.
	On failure, it returns (nil, <error message string>).]]
function ltool.evaluate_edit_fields(fields, ignore_name)
	local treedef = {}
	-- Validation helper: Checks for invalid characters for the fields “axiom” and the 4 rule sets
	local v = function(str)
		local match = string.match(str, "[^][abcdfABCDFGTR+-/*&^]")
		if(match==nil) then
			return true
		else
			return false
		end
	end
	-- Validation helper: Checks for balanced brackets
	local b = function(str)
		local brackets = 0
		for c=1, string.len(str) do
			local char = string.sub(str, c, c)
			if char == "[" then
				brackets = brackets + 1
			elseif char == "]" then
				brackets = brackets - 1
				if brackets < 0 then
					return false
				end
			end
		end
		return brackets == 0
	end

	if(v(fields.axiom) and v(fields.rules_a) and v(fields.rules_b) and v(fields.rules_c) and v(fields.rules_d)) then
		if(b(fields.axiom) and b(fields.rules_a) and b(fields.rules_b) and b(fields.rules_c) and b(fields.rules_d)) then
			treedef.rules_a = fields.rules_a
			treedef.rules_b = fields.rules_b
			treedef.rules_c = fields.rules_c
			treedef.rules_d = fields.rules_d
			treedef.axiom = fields.axiom
		else
			return nil, S("The brackets are unbalanced! For each of the axiom and the rule sets, each opening bracket must be matched by a closing bracket.")
		end
	else
		return nil, S("The axiom or one of the rule sets contains at least one invalid character.\nSee the cheat sheet for a list of allowed characters.")
	end
	treedef.trunk = fields.trunk
	treedef.leaves = fields.leaves
	treedef.leaves2 = fields.leaves2
	treedef.leaves2_chance = fields.leaves2_chance
	treedef.angle = tonumber(fields.angle)
	if(treedef.angle == nil) then
		return nil, S("The field \"Angle\" must contain a number.")
	end
	treedef.iterations = tonumber(fields.iterations)
	if(treedef.iterations == nil) then
		return nil, S("The field \"Iterations\" must contain a natural number greater or equal to 0.")
	elseif(treedef.iterations < 0) then
		return nil, S("The field \"Iterations\" must contain a natural number greater or equal to 0.")
	end
	treedef.random_level = tonumber(fields.random_level)
	if(treedef.random_level == nil) then
		return nil, S("The field \"Randomness level\" must contain a number.")
	end
	treedef.fruit = fields.fruit
	treedef.fruit_chance = tonumber(fields.fruit_chance)
	if(treedef.fruit_chance == nil) then
		return nil, S("The field \"Fruit chance\" must contain a number.")
	elseif(treedef.fruit_chance > 100 or treedef.fruit_chance < 0) then
		return nil, S("Fruit chance must be between 0% and 100%.")
	end
	if(fields.trunk_type == "single" or fields.trunk_type == "double" or fields.trunk_type == "crossed") then
		treedef.trunk_type = fields.trunk_type
	else
		return nil, S("Trunk type must be \"single\", \"double\" or \"crossed\".")
	end
	treedef.thin_branches = fields.thin_branches
	if(fields.thin_branches == "true") then
		treedef.thin_branches = true
	elseif(fields.thin_branches == "false") then
		treedef.thin_branches = false
	else
		return nil, S("Field \"Thin branches\" must be \"true\" or \"false\".")
	end
	local name = fields.name
	if(ignore_name ~= true and name == "") then
		return nil, S("Name is empty.")
	end
	return treedef, name
end


--[=[ Here come several utility functions ]=]

--[[ converts a given tree to field names, as if they were given to a
minetest.register_on_plyer_receive_fields callback function ]]
function ltool.tree_to_fields(tree)
	local s = function(i)
		if(i==nil) then
			return ""
		else
			return tostring(i)
		end
	end
	local fields = {}
	fields.axiom = s(tree.treedef.axiom)
	fields.rules_a = s(tree.treedef.rules_a)
	fields.rules_b = s(tree.treedef.rules_b)
	fields.rules_c = s(tree.treedef.rules_c)
	fields.rules_d = s(tree.treedef.rules_d)
	fields.trunk = s(tree.treedef.trunk)
	fields.leaves = s(tree.treedef.leaves)
	fields.leaves2 = s(tree.treedef.leaves2)
	fields.leaves2_chance = s(tree.treedef.leaves2)
	fields.fruit = s(tree.treedef.fruit)
	fields.fruit_chance = s(tree.treedef.fruit_chance)
	fields.angle = s(tree.treedef.angle)
	fields.iterations = s(tree.treedef.iterations)
	fields.random_level = s(tree.treedef.random_level)
	fields.trunk_type = s(tree.treedef.trunk_type)
	fields.thin_branches = s(tree.treedef.thin_branches)
	fields.name = s(tree.name)
	return fields
end



-- returns a simple table of all the tree IDs
function ltool.get_tree_ids()
	local ids = {}
	for tree_id, _ in pairs(ltool.trees) do
		table.insert(ids, tree_id)
	end
	table.sort(ids)
	return ids
end

--[[ In a table of tree IDs (returned by ltool.get_tree_ids, parameter tree_ids), this function
searches for the first occourance of the value searched_tree_id and returns its index.
This is basically a reverse lookup utility. ]]
function ltool.get_tree_id_index(searched_tree_id, tree_ids)
	for i=1, #tree_ids do
		local table_tree_id = tree_ids[i]
		if(searched_tree_id == table_tree_id) then
			return i
		end
	end
end

-- Returns the selected tree of the given player
function ltool.get_selected_tree(playername)
	local sel = ltool.playerinfos[playername].dbsel
	if(sel ~= nil) then
		local tree_id = ltool.playerinfos[playername].treeform.database.textlist[sel]
		if(tree_id ~= nil) then
			return ltool.trees[tree_id]
		end
	end
	return nil
end

-- Returns the ID of the selected tree of the given player
function ltool.get_selected_tree_id(playername)
	local sel = ltool.playerinfos[playername].dbsel
	if(sel ~= nil) then
		return ltool.playerinfos[playername].treeform.database.textlist[sel]
	end
	return nil
end


ltool.treeform = ltool.formspec_size..ltool.formspec_header(1)..ltool.tab_edit()

minetest.register_chatcommand("treeform",
{
	params = "",
	description = "Open L-System Tree Utility.",
	privs = {},
	func = function(playername, param)
		ltool.show_treeform(playername)
	end
})

minetest.register_chatcommand("lplant",
{
	description = S("Plant a L-system tree at the specified position"),
	privs = { lplant = true },
	params = S("<tree ID> <x> <y> <z> [<seed>]"),
	func = function(playername, param)
		local p = {}
		local tree_id, x, y, z, seed = string.match(param, "^([^ ]+) +([%d.-]+)[, ] *([%d.-]+)[, ] *([%d.-]+) *([%d.-]*)")
		tree_id, p.x, p.y, p.z, seed = tonumber(tree_id), tonumber(x), tonumber(y), tonumber(z), tonumber(seed)
		if not tree_id or not p.x or not p.y or not p.z then
			return false, S("Invalid usage, see /help lplant.")
		end
		local lm = tonumber(minetest.settings:get("map_generation_limit") or 31000)
		if p.x < -lm or p.x > lm or p.y < -lm or p.y > lm or p.z < -lm or p.z > lm then
			return false, S("Cannot plant tree out of map bounds!")
		end

		local success = ltool.plant_tree(tree_id, p, seed)
		if success == false then
			return false, S("Unknown tree ID!")
		else
			return true
		end
	end
})

function ltool.dbsel_to_tree(dbsel, playername)
	return ltool.trees[ltool.playerinfos[playername].treeform.database.textlist[dbsel]]
end

function ltool.save_fields(playername,formname,fields)
	if not fields.thin_branches then
		fields.thin_branches = ltool.playerinfos[playername].treeform.edit.thin_branches
	end
	if(formname=="ltool:treeform_edit") then
		ltool.playerinfos[playername].treeform.edit.fields = fields
	elseif(formname=="ltool:treeform_database") then
		ltool.playerinfos[playername].treeform.database.fields = fields
	elseif(formname=="ltool:treeform_plant") then
		ltool.playerinfos[playername].treeform.plant.fields = fields
	end
end

local function handle_sapling_button_database_plant(seltree, seltree_id, privs, formname, fields, playername)
	if(seltree ~= nil) then
		if(privs.lplant ~= true) then
			ltool.save_fields(playername, formname, fields)
			local message = S("You can't request saplings, you need to have the \"lplant\" privilege.")
			ltool.show_dialog(playername, "ltool:treeform_error_sapling", message)
			return false
		end
		local seed = nil
		if(tonumber(fields.seed)~=nil) then
			seed = tonumber(fields.seed)
		end
		if ltool.trees[seltree_id] then
			local ret, ret2 = ltool.give_sapling(ltool.trees[seltree_id].treedef, seed, playername, true, ltool.trees[seltree_id].name)
			if(ret==false and ret2==2) then
				ltool.save_fields(playername, formname, fields)
				ltool.show_dialog(playername, "ltool:treeform_error_sapling", S("Error: The sapling could not be given to you. Probably your inventory is full."))
			end
		end
	end
end

--[=[ Callback functions start here ]=]
function ltool.process_form(player,formname,fields)
	local playername = player:get_player_name()

	local seltree = ltool.get_selected_tree(playername)
	local seltree_id = ltool.get_selected_tree_id(playername)
	local privs = minetest.get_player_privs(playername)
	local s = function(input)
		local ret
		if(input==nil) then
			ret = ""
		else
			ret = F(tostring(input))
		end
		return ret
	end
	-- Update thin_branches field
	if(formname == "ltool:treeform_edit") then
		if(not fields.thin_branches) then
			fields.thin_branches = ltool.playerinfos[playername].treeform.edit.thin_branches
			if(not fields.thin_branches) then
				minetest.log("error", "[ltool] thin_branches field of "..playername.." is nil!")
			end
		else
			ltool.playerinfos[playername].treeform.edit.thin_branches = fields.thin_branches
		end
	end
	--[[ process clicks on the tab header ]]
	if(formname == "ltool:treeform_edit" or formname == "ltool:treeform_database" or formname == "ltool:treeform_plant" or formname == "ltool:treeform_help") then
		if fields.ltool_tab ~= nil then
			ltool.save_fields(playername, formname, fields)
			local tab = tonumber(fields.ltool_tab)
			local formspec, subformname, contents
			if(tab==1) then
				contents = ltool.tab_edit(ltool.playerinfos[playername].treeform.edit.fields, privs.ledit, privs.lplant)
				subformname = "edit"
			elseif(tab==2) then
				contents = ltool.tab_database(ltool.playerinfos[playername].dbsel, playername)
				subformname = "database"
			elseif(tab==3) then
				if(ltool.number_of_trees > 0) then
					contents = ltool.tab_plant(seltree, ltool.playerinfos[playername].treeform.plant.fields, privs.lplant)
				else
					contents = ltool.tab_plant(nil, nil, privs.lplant)
				end
				subformname = "plant"
			elseif(tab==4) then
				contents = ltool.tab_help(ltool.playerinfos[playername].treeform.help.tab)
				subformname = "help"
			end
			formspec = ltool.formspec_size..ltool.formspec_header(tab)..contents
			minetest.show_formspec(playername, "ltool:treeform_" .. subformname, formspec)
			return
		end
	end
	--[[ "Plant" tab ]]
	if(formname == "ltool:treeform_plant") then
		if(fields.plant_plant) then
			if(seltree ~= nil) then
				if(privs.lplant ~= true) then
					ltool.save_fields(playername, formname, fields)
					local message = S("You can't plant trees, you need to have the \"lplant\" privilege.")
					ltool.show_dialog(playername, "ltool:treeform_error_lplant", message)
					return
				end
				minetest.log("action","[ltool] Planting tree")
				local treedef = seltree.treedef

				local x,y,z = tonumber(fields.x), tonumber(fields.y), tonumber(fields.z)
				local distance = tonumber(fields.distance)
				local tree_pos
				local fail_coordinates = function()
					ltool.save_fields(playername, formname, fields)
					ltool.show_dialog(playername, "ltool:treeform_error_badplantfields", S("Error: When using coordinates, you have to specify numbers in the fields \"x\", \"y\", \"z\"."))
				end
				local fail_distance = function()
					ltool.save_fields(playername, formname, fields)
					ltool.show_dialog(playername, "ltool:treeform_error_badplantfields", S("Error: When using viewing direction for planting trees,\nyou must specify how far away you want the tree to be placed in the field \"Distance\"."))
				end
				if(fields.plantmode == F(S("Absolute coordinates"))) then
					if(type(x)~="number" or type(y) ~= "number" or type(z) ~= "number") then
						fail_coordinates()
						return
					end
					tree_pos = {x=x, y=y, z=z}
				elseif(fields.plantmode == F(S("Relative coordinates"))) then
					if(type(x)~="number" or type(y) ~= "number" or type(z) ~= "number") then
						fail_coordinates()
						return
					end
					tree_pos = player:get_pos()
					tree_pos.x = tree_pos.x + x
					tree_pos.y = tree_pos.y + y
					tree_pos.z = tree_pos.z + z
				elseif(fields.plantmode == F(S("Distance in viewing direction"))) then
					if(type(distance)~="number") then
						fail_distance()
						return
					end
					tree_pos = vector.round(vector.add(player:get_pos(), vector.multiply(player:get_look_dir(), distance)))
				else
					minetest.log("error", "[ltool] fields.plantmode = "..tostring(fields.plantmode))
				end
	
				if(tonumber(fields.seed)~=nil) then
					treedef.seed = tonumber(fields.seed)
				end
	
				ltool.plant_tree(seltree_id, tree_pos)
	
				treedef.seed = nil
			end
		elseif(fields.sapling) then
			local ret = handle_sapling_button_database_plant(seltree, seltree_id, privs, formname, fields, playername)
			if ret == false then
				return
			end
		end
	--[[ "Edit" tab ]]
	elseif(formname == "ltool:treeform_edit") then
		if(fields.edit_save or fields.edit_sapling) then
			local param1, param2
			param1, param2 = ltool.evaluate_edit_fields(fields, fields.edit_sapling ~= nil)
			if(fields.edit_save and privs.ledit ~= true) then
				ltool.save_fields(playername, formname, fields)
				local message = S("You can't save trees, you need to have the \"ledit\" privilege.")
				ltool.show_dialog(playername, "ltool:treeform_error_ledit", message)
				return
			end
			if(fields.edit_sapling and privs.lplant ~= true) then
				ltool.save_fields(playername, formname, fields)
				local message = S("You can't request saplings, you need to have the \"lplant\" privilege.")
				ltool.show_dialog(playername, "ltool:treeform_error_ledit", message)
				return
			end
			local tree_ok = true
			local treedef, name
			if(param1 ~= nil) then
				treedef = param1
				name = param2
				for k,v in pairs(ltool.trees) do
					if(fields.edit_save and v.name == name) then
						ltool.save_fields(playername, formname, fields)
						if(v.author == playername) then
							local formspec = "size[6,2;]label[0,0.2;You already have a tree with this name.\nDo you want to replace it?]"..
							"button[0,1.5;3,1;replace_yes;"..F(S("Yes")).."]"..
							"button[3,1.5;3,1;replace_no;"..F(S("No")).."]"
							minetest.show_formspec(playername, "ltool:treeform_replace", formspec)
						else
							ltool.show_dialog(playername, "ltool:treeform_error_nameclash", S("Error: This name is already taken by someone else."))
						end
						return
					end
				end
			else
				tree_ok = false
			end
			ltool.save_fields(playername, formname, fields)
			if(tree_ok == true) then
				if fields.edit_save then
					ltool.add_tree(name, playername, treedef)
				elseif fields.edit_sapling then
					local ret, ret2 = ltool.give_sapling(treedef, tostring(ltool.seed), playername, true, fields.name)
					if(ret==false and ret2==2) then
						ltool.save_fields(playername, formname, fields)
						ltool.show_dialog(playername, "ltool:treeform_error_sapling", S("Error: The sapling could not be given to you. Probably your inventory is full."))
					end
				end
			else
				local message = S("Error: The tree definition is invalid.").."\n"..
				F(param2)
				ltool.show_dialog(playername, "ltool:treeform_error_badtreedef", message)
			end
		end
		if(fields.edit_clear) then
			local privs = minetest.get_player_privs(playername)
			ltool.save_fields(playername, formname, ltool.default_edit_fields)
			local formspec = ltool.formspec_size..ltool.formspec_header(1)..ltool.tab_edit(ltool.default_edit_fields, privs.ledit, privs.lplant)

			--[[ hacky_spaces is part of a workaround, see comment on hacky_spaces in ltool.join.
			This workaround will slightly change the formspec by adding 0-5 spaces
			to the end, changing the number of spaces on each send. This forces
			Minetest to re-send the formspec.
			Spaces are completely harmless in a formspec.]]
			-- BEGIN OF WORKAROUND
			local hacky_spaces = ltool.playerinfos[playername].treeform.hacky_spaces
			hacky_spaces = hacky_spaces .. " "
			if string.len(hacky_spaces) > 5 then
				hacky_spaces = ""
			end
			ltool.playerinfos[playername].treeform.hacky_spaces = hacky_spaces
			local real_formspec = formspec .. hacky_spaces
			-- END OF WORKAROUND

			minetest.show_formspec(playername, "ltool:treeform_edit", real_formspec)
		end
		if(fields.edit_axiom or fields.edit_rules_a or fields.edit_rules_b or fields.edit_rules_c or fields.edit_rules_d) then
			local fragment
			if(fields.edit_axiom) then
				fragment = "axiom;"..F(S("Axiom"))..";"..s(fields.axiom)
			elseif(fields.edit_rules_a) then
				fragment = "rules_a;"..F(S("Rules set A"))..";"..s(fields.rules_a)
			elseif(fields.edit_rules_b) then
				fragment = "rules_b;"..F(S("Rules set B"))..";"..s(fields.rules_b)
			elseif(fields.edit_rules_c) then
				fragment = "rules_c;"..F(S("Rules set C"))..";"..s(fields.rules_c)
			elseif(fields.edit_rules_d) then
				fragment = "rules_d;"..F(S("Rules set D"))..";"..s(fields.rules_d)
			end

			ltool.save_fields(playername, formname, fields)
			local formspec = ltool.formspec_editplus(fragment)
			minetest.show_formspec(playername, "ltool:treeform_editplus", formspec)
		end
		if(mod_select_item and (fields.edit_trunk or fields.edit_leaves or fields.edit_leaves2 or fields.edit_fruit)) then
			ltool.save_fields(playername, formname, fields)
			-- Prepare sorting.
			-- Move tree, leaves, apple/leafdecay nodes to the beginning
			local compare_group, fruit
			if fields.edit_trunk then
				compare_group = "tree"
			elseif fields.edit_leaves or fields.edit_leaves2 then
				compare_group = "leaves"
			elseif fields.edit_fruit or fields.edit_fruit then
				compare_group = "leafdecay"
				local alias = minetest.registered_aliases["mapgen_apple"]
				if alias and minetest.registered_nodes[alias] then
					fruit = alias
				end
			end
			select_item.show_dialog(playername, "ltool:node", function(itemstring)
				if itemstring ~= "air" and minetest.registered_nodes[itemstring] ~= nil then
					return true
				end
			end,
			function(i1, i2)
				if fruit and i1 == fruit then
					return true
				end
				if fruit and i2 == fruit then
					return false
				end
				local i1t = minetest.get_item_group(i1, compare_group)
				local i2t = minetest.get_item_group(i2, compare_group)
				local i1d = minetest.registered_items[i1].description
				local i2d = minetest.registered_items[i2].description
				local i1nici = minetest.get_item_group(i1, "not_in_creative_inventory")
				local i2nici = minetest.get_item_group(i2, "not_in_creative_inventory")
				if (i1d == "" and i2d ~= "") then
					return false
				elseif (i1d ~= "" and i2d == "") then
					return true
				end
				if (i1nici == 1 and i2nici == 0) then
					return false
				elseif (i1nici == 0 and i2nici == 1) then
					return true
				end
				if i1t < i2t then
					return false
				elseif i1t > i2t then
					return true
				end
				return i1 < i2
			end)
		end
	--[[ Larger edit fields for axiom and rules fields ]]
	elseif(formname == "ltool:treeform_editplus") then
		local editfields = ltool.playerinfos[playername].treeform.edit.fields
		local function addchar(c)
			local fragment
			if(c=="P") then c = "[" end
			if(c=="p") then c = "]" end
			if(fields.axiom) then
				fragment = "axiom;"..F(S("Axiom"))..";"..s(fields.axiom..c)
			elseif(fields.rules_a) then
				fragment = "rules_a;"..F(S("Rules set A"))..";"..s(fields.rules_a..c)
			elseif(fields.rules_b) then
				fragment = "rules_b;"..F(S("Rules set B"))..";"..s(fields.rules_b..c)
			elseif(fields.rules_c) then
				fragment = "rules_c;"..F(S("Rules set C"))..";"..s(fields.rules_c..c)
			elseif(fields.rules_d) then
				fragment = "rules_d;"..F(S("Rules set D"))..";"..s(fields.rules_d..c)
			end
			local formspec = ltool.formspec_editplus(fragment)
			minetest.show_formspec(playername, "ltool:treeform_editplus", formspec)
		end
		if(fields.editplus_save) then
			local function o(writed, writer)
				if(writer~=nil) then
					return writer
				else
					return writed
				end
			end
			editfields.axiom = o(editfields.axiom, fields.axiom)
			editfields.rules_a = o(editfields.rules_a, fields.rules_a)
			editfields.rules_b = o(editfields.rules_b, fields.rules_b)
			editfields.rules_c = o(editfields.rules_c, fields.rules_c)
			editfields.rules_d = o(editfields.rules_d, fields.rules_d)
			local formspec = ltool.formspec_size..ltool.formspec_header(1)..ltool.tab_edit(editfields, privs.ledit, privs.lplant)
			minetest.show_formspec(playername, "ltool:treeform_edit", formspec)
		elseif(fields.editplus_cancel or fields.quit) then
			local formspec = ltool.formspec_size..ltool.formspec_header(1)..ltool.tab_edit(editfields, privs.ledit, privs.lplant)
			minetest.show_formspec(playername, "ltool:treeform_edit", formspec)
		else
			for id, field in pairs(fields) do
				if(string.sub(id,1,11) == "editplus_c_") then
					local char = string.sub(id,12,12)
					addchar(char)
				end
			end
		end
	--[[ "Database" tab ]]
	elseif(formname == "ltool:treeform_database") then
		if(fields.treelist) then
			local event = minetest.explode_textlist_event(fields.treelist)
			if(event.type == "CHG") then
				ltool.playerinfos[playername].dbsel = event.index
				local formspec = ltool.formspec_size..ltool.formspec_header(2)..ltool.tab_database(event.index, playername)
				minetest.show_formspec(playername, "ltool:treeform_database", formspec)
			end
		elseif(fields.database_copy) then
			if(seltree ~= nil) then
				if(ltool.playerinfos[playername] ~= nil) then
					local formspec = ltool.formspec_size..ltool.formspec_header(1)..ltool.tab_edit(ltool.tree_to_fields(seltree), privs.ledit, privs.lplant)
					minetest.show_formspec(playername, "ltool:treeform_edit", formspec)
				end
			else
				ltool.show_dialog(playername, "ltool:treeform_error_nodbsel", S("Error: No tree is selected."))
			end
		elseif(fields.database_update) then
			local formspec = ltool.formspec_size..ltool.formspec_header(2)..ltool.tab_database(ltool.playerinfos[playername].dbsel, playername)
			minetest.show_formspec(playername, "ltool:treeform_database", formspec)

		elseif(fields.database_delete) then
			if(privs.ledit ~= true) then
				ltool.save_fields(playername, formname, fields)
				local message = S("You can't delete trees, you need to have the \"ledit\" privilege.")
				ltool.show_dialog(playername, "ltool:treeform_error_ledit_db", message)
				return
			end
			if(seltree ~= nil) then
				if(playername == seltree.author) then
					local remove_id = ltool.get_selected_tree_id(playername)
					if(remove_id ~= nil) then
						ltool.remove_tree(remove_id)
						local formspec = ltool.formspec_size..ltool.formspec_header(2)..ltool.tab_database(ltool.playerinfos[playername].dbsel, playername)
						minetest.show_formspec(playername, "ltool:treeform_database", formspec)
					end
				else
					ltool.show_dialog(playername, "ltool:treeform_error_delete", S("Error: This tree is not your own. You may only delete your own trees."))
				end
			else
				ltool.show_dialog(playername, "ltool:treeform_error_nodbsel", S("Error: No tree is selected."))
			end
		elseif(fields.database_rename) then
			if(seltree ~= nil) then
				if(privs.ledit ~= true) then
					ltool.save_fields(playername, formname, fields)
					local message = S("You can't rename trees, you need to have the \"ledit\" privilege.")
					ltool.show_dialog(playername, "ltool:treeform_error_ledit_db", message)
					return
				end
				if(playername == seltree.author) then
					local formspec = "field[newname;"..F(S("New name:"))..";"..F(seltree.name).."]"
					minetest.show_formspec(playername, "ltool:treeform_rename", formspec)
				else
					ltool.show_dialog(playername, "ltool:treeform_error_rename_forbidden", S("Error: This tree is not your own. You may only rename your own trees."))
				end
			else
				ltool.show_dialog(playername, "ltool:treeform_error_nodbsel", S("Error: No tree is selected."))
			end
		elseif(fields.sapling) then
			local ret = handle_sapling_button_database_plant(seltree, seltree_id, privs, formname, fields, playername)
			if ret == false then
				return
			end
		end
	--[[ Process "Do you want to replace this tree?" dialog ]]
	elseif(formname == "ltool:treeform_replace") then
		local editfields = ltool.playerinfos[playername].treeform.edit.fields
		local newtreedef, newname = ltool.evaluate_edit_fields(editfields)
		if(privs.ledit ~= true) then
			local message = S("You can't overwrite trees, you need to have the \"ledit\" privilege.")
			minetest.show_dialog(playername, "ltool:treeform_error_ledit", message)
			return
		end
		if(fields.replace_yes) then
			for tree_id,tree in pairs(ltool.trees) do
				if(tree.name == newname) then
					--[[ The old tree is deleted and a
					new one with a new ID is created ]]
					local new_tree_id = ltool.next_tree_id
					ltool.trees[new_tree_id] = {}
					ltool.trees[new_tree_id].treedef = newtreedef
					ltool.trees[new_tree_id].name = newname
					ltool.trees[new_tree_id].author = tree.author
					ltool.next_tree_id = ltool.next_tree_id + 1
					ltool.trees[tree_id] = nil
					ltool.playerinfos[playername].dbsel = ltool.number_of_trees
				end
			end
		end
		local formspec = ltool.formspec_size..ltool.formspec_header(1)..ltool.tab_edit(editfields, privs.ledit, privs.lplant)
		minetest.show_formspec(playername, "ltool:treeform_edit", formspec)
	elseif(formname == "ltool:treeform_help") then
		local tab = tonumber(fields.ltool_help_tab)
		if(tab ~= nil) then
			ltool.playerinfos[playername].treeform.help.tab = tab
			local formspec = ltool.formspec_size..ltool.formspec_header(4)..ltool.tab_help(tab)
			minetest.show_formspec(playername, "ltool:treeform_help", formspec)
		end
		if(fields.create_template) then
			local newfields = {
				axiom="FFFFFAFFBF",
				rules_a="[&&&FFFFF&&FFFF][&&&++++FFFFF&&FFFF][&&&----FFFFF&&FFFF]",
				rules_b="[&&&++FFFFF&&FFFF][&&&--FFFFF&&FFFF][&&&------FFFFF&&FFFF]",
				trunk="mapgen_tree",
				leaves="mapgen_leaves",
				leaves2_chance="0",
				angle="30",
				iterations="2",
				random_level="0",
				trunk_type="single",
				thin_branches="true",
				fruit_chance="10",
				fruit="mapgen_apple",
				name = "Example Tree "..ltool.next_tree_id
			}
			ltool.save_fields(playername, formname, newfields)
			local formspec = ltool.formspec_size..ltool.formspec_header(1)..ltool.tab_edit(newfields, privs.ledit, privs.lplant)
			minetest.show_formspec(playername, "ltool:treeform_edit", formspec)
		end
	--[[ Tree renaming dialog ]]
	elseif(formname == "ltool:treeform_rename") then
		if(privs.ledit ~= true) then
			ltool.save_fields(playername, formname, fields)
			local message = S("You can't delete trees, you need to have the \"ledit\" privilege.")
			ltool.show_dialog(playername, "ltool:treeform_error_ledit_delete", message)
			return
		end
		if(fields.newname ~= "" and fields.newname ~= nil) then
			ltool.rename_tree(ltool.get_selected_tree_id(playername), fields.newname)
			local formspec = ltool.formspec_size..ltool.formspec_header(2)..ltool.tab_database(ltool.playerinfos[playername].dbsel, playername)
			minetest.show_formspec(playername, "ltool:treeform_database", formspec)
		else
			ltool.show_dialog(playername, "ltool:treeform_error_bad_rename", S("Error: This name is empty. The tree name must be non-empty."))
		end
	--[[ Here come various error messages to handle ]]
	elseif(formname == "ltool:treeform_error_badtreedef" or formname == "ltool:treeform_error_nameclash" or formname == "ltool:treeform_error_ledit") then
		local formspec = ltool.formspec_size..ltool.formspec_header(1)..ltool.tab_edit(ltool.playerinfos[playername].treeform.edit.fields, privs.ledit, privs.lplant)
		minetest.show_formspec(playername, "ltool:treeform_edit", formspec)
	elseif(formname == "ltool:treeform_error_badplantfields" or formname == "ltool:treeform_error_sapling" or formname == "ltool:treeform_error_lplant") then
		local formspec = ltool.formspec_size..ltool.formspec_header(3)..ltool.tab_plant(seltree, ltool.playerinfos[playername].treeform.plant.fields, privs.lplant)
		minetest.show_formspec(playername, "ltool:treeform_plant", formspec)
	elseif(formname == "ltool:treeform_error_delete" or formname == "ltool:treeform_error_rename_forbidden" or formname == "ltool:treeform_error_nodbsel" or formname == "ltool:treeform_error_ledit_db") then
		local formspec = ltool.formspec_size..ltool.formspec_header(2)..ltool.tab_database(ltool.playerinfos[playername].dbsel, playername)
		minetest.show_formspec(playername, "ltool:treeform_database", formspec)
	elseif(formname == "ltool:treeform_error_bad_rename") then
		local formspec = "field[newname;"..F(S("New name:"))..";"..F(seltree.name).."]"
		minetest.show_formspec(playername, "ltool:treeform_rename", formspec)
	else
		-- Action for Inventory++ button
		if fields.ltool and minetest.get_modpath("inventory_plus") then
			ltool.show_treeform(playername)
			return
		end
	end
end

if mod_select_item then
	select_item.register_on_select_item(function(playername, dialogname, itemstring)
		if dialogname == "ltool:node" then
			if itemstring then
				local f = ltool.playerinfos[playername].treeform.edit.fields
				if f.edit_trunk then
					f.trunk = itemstring
				elseif f.edit_leaves then
					f.leaves = itemstring
				elseif f.edit_leaves2 then
					f.leaves2 = itemstring
				elseif f.edit_fruit then
					f.fruit = itemstring
				end
			end
			ltool.show_treeform(playername)
			return false
		end
	end)
end

--[[ These 2 functions are basically just table initializions and cleanups ]]
function ltool.leave(player)
	ltool.playerinfos[player:get_player_name()] = nil
end

function ltool.join(player)
	local infotable = {}
	infotable.dbsel = nil
	infotable.treeform = {}
	infotable.treeform.database = {}
	--[[ This table stores a mapping of the textlist IDs in the database formspec and the tree IDs.
	It is updated each time ltool.tab_database is called. ]]
	infotable.treeform.database.textlist = {}
	--[[ the “fields” tables store the values of the input fields of a formspec. It is updated
	whenever the formspec is changed, i.e. on tab change ]]
	infotable.treeform.database.fields = {}
	infotable.treeform.plant = {}
	infotable.treeform.plant.fields = {}
	infotable.treeform.edit = {}
	infotable.treeform.edit.fields = ltool.default_edit_fields
	infotable.treeform.edit.thin_branches = "true"
	infotable.treeform.help = {}
	infotable.treeform.help.tab = 1
	--[[ Workaround for annoying bug in Minetest: When you call the identical formspec twice,
	Minetest does not send the second one. This is an issue when the player has changed the
	input fields in the meanwhile, resetting fields will fail sometimes.
	TODO: Remove workaround when not needed anymore. ]]
	-- BEGIN OF WORKAROUND
	infotable.treeform.hacky_spaces = ""
	-- END OF WORKAROUND

	ltool.playerinfos[player:get_player_name()] = infotable

	-- Add Inventory++ support
	if minetest.get_modpath("inventory_plus") then
		inventory_plus.register_button(player, "ltool", S("L-System Tree Utility"))
	end
end

function ltool.save_to_file()
	local savetable = {}
	savetable.trees = ltool.trees
	savetable.number_of_trees = ltool.number_of_trees
	savetable.next_tree_id = ltool.next_tree_id
	local savestring = minetest.serialize(savetable)
	local filepath = minetest.get_worldpath().."/ltool.mt"
	local file = io.open(filepath, "w")
	if(file) then
		file:write(savestring)
		io.close(file)
		minetest.log("action", "[ltool] Tree data saved to "..filepath..".")
	else
		minetest.log("error", "[ltool] Failed to write ltool data to "..filepath".")
	end
	
end

minetest.register_on_player_receive_fields(ltool.process_form)

minetest.register_on_leaveplayer(ltool.leave)

minetest.register_on_joinplayer(ltool.join)

minetest.register_on_shutdown(ltool.save_to_file)

local button_action = function(player)
	ltool.show_treeform(player:get_player_name())
end

if minetest.get_modpath("unified_inventory") ~= nil then
	unified_inventory.register_button("ltool", {
		type = "image",
		image = "ltool_sapling.png",
		tooltip = S("L-System Tree Utility"),
		action = button_action,
	})
end

if minetest.get_modpath("sfinv_buttons") ~= nil then
	sfinv_buttons.register_button("ltool", {
		title = S("L-System Tree Utility"),
		tooltip = S("Invent your own trees and plant them"),
		image = "ltool_sapling.png",
		action = button_action,
	})
end


