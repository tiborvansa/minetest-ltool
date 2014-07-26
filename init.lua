ltool = {}

ltool.playerinfos = {}
ltool.emptytreedef = {
	axiom="",
	rules_a="",
	rules_b="",
	rules_c="",
	rules_d="",
	trunk="",
	leaves="",
	leaves2="",
	leaves2_chance="",
	fruit="",
	fruit_chance="",
	angle="",
	iterations="",
	random_level="",
	trunk_type="",
	thin_branches="",
}

minetest.register_node("ltool:sapling", {
	description = "custom L-system tree sapling",
	stack_max = 1,
	drawtype = "plantlike",
	tiles = { "ltool_sapling.png" },
	inventory_image = "ltool_sapling.png",
	wield_image = "ltool_sapling.png",
	paramtype = "light",
	paramtype2= "wallmounted",
	walkable = false,
	buildable_to = true,
	groups = { dig_immediate = 3, not_in_creative_inventory=1 },
	after_place_node = function(pos, placer, itemstack, pointed_thing)
		-- Transfer metadata and start timer
		local nodemeta = minetest.get_meta(pos)
		local itemmeta = itemstack:get_metadata()
		nodemeta:set_string("treedef", itemmeta)
		local timer = minetest.get_node_timer(pos)
		timer:start(5)
	end,
	on_timer = function(pos, elapsed)
		-- Place tree
		local meta = minetest.get_meta(pos)
		local treedef = minetest.deserialize(meta:get_string("treedef"))
		minetest.remove_node(pos)
		minetest.spawn_tree(pos, treedef)
	end,
})

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
		ltool.trees = {}
		ltool.number_of_trees = 0
		ltool.next_tree_id = 1
	end
end

function ltool.add_tree(name, author, treedef)
	local id = ltool.next_tree_id
	ltool.trees[id] = {name = name, author = author, treedef = treedef}
	ltool.next_tree_id = ltool.next_tree_id + 1
	ltool.number_of_trees = ltool.number_of_trees + 1
	return id
end

ltool.seed = os.time()

ltool.loadtreeform = "size[6,7]"

function ltool.header(index)
	return "tabheader[0,0;ltool_tab;Edit,Database,Plant,Cheat sheet;"..tostring(index)..";true;false]"
end

function ltool.edit(tree)
	local treedef, name
	if(tree==nil) then
		treedef = ltool.emptytreedef
		name = ""
	else
		treedef = tree.treedef
		name = tree.name
	end
	local s = function(input)
		if(input==nil) then
			ret = ""
		else
			ret = minetest.formspec_escape(tostring(input))
		end
		return ret
	end
	return ""..
	"field[0.2,-4;6,10;axiom;Axiom;"..s(treedef.axiom).."]"..
	"field[0.2,-3.4;6,10;rules_a;Rules set A;"..s(treedef.rules_a).."]"..
	"field[0.2,-2.7;6,10;rules_b;Rules set B;"..s(treedef.rules_b).."]"..
	"field[0.2,-2.1;6,10;rules_c;Rules set C;"..s(treedef.rules_c).."]"..
	"field[0.2,-1.5;6,10;rules_d;Rules set D;"..s(treedef.rules_d).."]"..
	"field[0.2,-0.9;3,10;trunk;Trunk node name;"..s(treedef.trunk).."]"..
	"field[0.2,-0.3;3,10;leaves;Leaves node name;"..s(treedef.leaves).."]"..
	"field[0.2,0.3;3,10;leaves2;Secondary leaves node name;"..s(treedef.leaves2).."]"..
	"field[0.2,0.9;3,10;leaves2_chance;Secondary leaves chance (in percent);"..s(treedef.leaves2_chance).."]"..
	"field[0.2,1.5;3,10;fruit;Fruit node name;"..s(treedef.fruit).."]"..
	"field[0.2,2.1;3,10;fruit_chance;Fruit chance (in percent);"..s(treedef.fruit_chance).."]"..

	"field[3.2,-0.9;3,10;angle;Angle (in degrees);"..s(treedef.angle).."]"..
	"field[3.2,-0.3;3,10;iterations;Iterations;"..s(treedef.iterations).."]"..
	"field[3.2,0.3;3,10;random_level;Randomness level;"..s(treedef.random_level).."]"..
	"field[3.2,0.9;3,10;trunk_type;Trunk type (single/double/crossed);"..s(treedef.trunk_type).."]"..
	"field[3.2,1.5;3,10;thin_branches;Thin branches? (true/false);"..s(treedef.thin_branches).."]"..
	"field[3.2,2.1;3,10;name;Name;"..s(name).."]"..
	"button[0,6.5;2,1;edit_save;Save]"
end

function ltool.database(index, playername)
	local treestr, tree_ids = ltool.build_tree_textlist(index, playername)
	if(treestr ~= nil) then
		local indexstr
		if(index == nil) then
			indexstr = ""
		else
			indexstr = tostring(index)
		end
		ltool.playerinfos[playername].treeform.database.textlist = tree_ids
		return ""..
		"textlist[0,0;5,6;treelist;"..treestr..";"..tostring(index)..";false]"..
		"button[0,6;2,1;database_rename;Rename tree]"..
		"button[2.1,6;2,1;database_delete;Delete tree]"..
		"button[0,6.5;2,1;database_copy;Copy to editor]"..
		"button[2.1,6.5;2,1;database_update;Reload database]"
	else
		return "label[0,0;The tree database is empty.]"..
		"button[2.1,6.5;2,1;database_update;Reload database]"
	end
end

function ltool.cheat_sheet()
	return ""..
	"tablecolumns[text;text]"..
	"tableoptions[background=#000000;highlight=#000000;border=false]"..
	"table[0,0;6,7;cheat_sheet;"..
	"Symbol,Action,"..
	"G,Move forward one unit with the pen up,"..
	"F,Move forward one unit with the pen down drawing trunks and branches,"..
	"f,Move forward one unit with the pen down drawing leaves (100% chance),"..
	"T,Move forward one unit with the pen down drawing trunks only,"..
	"R,Move forward one unit with the pen down placing fruit,"..
	"A,Replace with rules set A,"..
	"B,Replace with rules set B,"..
	"C,Replace with rules set C,"..
	"D,Replace with rules set D,"..
	"a,Replace with rules set A\\, chance 90%,"..
	"b,Replace with rules set B\\, chance 80%,"..
	"c,Replace with rules set C\\, chance 70%,"..
	"d,Replace with rules set D\\, chance 60%,"..
	"+,Yaw the turtle right by angle parameter,"..
	"-,Yaw the turtle left by angle parameter,"..
	"&,Pitch the turtle down by angle parameter,"..
	"^,Pitch the turtle up by angle parameter,"..
	"/,Roll the turtle to the right by angle parameter,"..
	"*,Roll the turtle to the left by angle parameter,"..
	"\\[,Save in stack current state info,"..
	"\\],Recover from stack state info]"
end

function ltool.evaluate_edit_fields(fields)
	local treedef = {}
	treedef.axiom = fields.axiom
	treedef.rules_a = fields.rules_a
	treedef.rules_b = fields.rules_b
	treedef.rules_c = fields.rules_c
	treedef.rules_d = fields.rules_d
	treedef.trunk = fields.trunk
	treedef.leaves = fields.leaves
	treedef.leaves2 = fields.leaves2
	treedef.leaves2_chance = fields.leaves2_chance
	treedef.angle = tonumber(fields.angle)
	if(treedef.angle == nil) then
		return nil, "The field \"Angle\" must contain a number."
	end
	treedef.iterations = tonumber(fields.iterations)
	if(treedef.iterations == nil) then
		return nil, "The field \"Iterations\" must contain a natural number greater or equal to 0."
	elseif(treedef.iterations < 0) then
		return nil, "The field \"Iterations\" must contain a natural number greater or equal to 0."
	end
	treedef.random_level = tonumber(fields.random_level)
	if(treedef.random_level == nil) then
		return nil, "The field \"Randomness level\" must contain a number."
	end
	treedef.fruit = fields.fruit
	treedef.fruit_chance = tonumber(fields.fruit_chance)
	if(treedef.fruit_chance == nil) then
		return nil, "The field \"Fruit chance\" must contain a number."
	elseif(treedef.fruit_chance > 100 or treedef.fruit_chance < 0) then
		return nil, "Fruit chance must be between 0% and 100%."
	end
	if(fields.trunk_type == "single" or fields.trunk_type == "double" or fields.trunk_type == "crossed") then
		treedef.trunk_type = fields.trunk_type
	else
		return nil, "Trunk type must be \"single\", \"double\" or \"crossed\"."
	end
	treedef.thin_branches = fields.thin_branches
	if(fields.thin_branches == "true") then
		treedef.thin_branches = true
	elseif(fields.thin_branches == "false") then
		treedef.thin_branches = false
	else
		return nil, "Field \"Thin branches?\" must be \"true\" or \"false\"."
	end
	local name = fields.name
	if(name == "") then
		return nil, "Name is empty."
	end
	return treedef, name
end

function ltool.plant(tree)
	if(tree ~= nil) then
		return ""..
		"label[0,-0.2;Selected tree: "..minetest.formspec_escape(tree.name).."]"..
		"dropdown[-0.1,0.5;5;plantmode;Absolute coordinates,Relative coordinates;1]"..
		"field[0.2,-2.7;6,10;x;x;]"..
		"field[0.2,-2.1;6,10;y;y;]"..
		"field[0.2,-1.5;6,10;z;z;]"..
		"field[0.2,0;6,10;seed;Seed;"..ltool.seed.."]"..
		"button[0,6.5;2,1;plant_plant;Plant]"..
		"button[2.1,6.5;2,1;sapling;Give me a sapling]"
	else
		return "label[0,0;No tree in database selected or database is empty.]"
	end
end


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
		string = string .. colorstring .. tostring(tree_id) .. ": " .. minetest.formspec_escape(tree.name)
		if(i~=#tree_ids) then
			string = string .. ","
		end
	end
	return string, tree_ids
end

-- returns a simple table of all the tree IDs
function ltool.get_tree_ids()
	local ids = {}
	for tree_id, _ in pairs(ltool.trees) do
		table.insert(ids, tree_id)
	end
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

function ltool.get_selected_tree_id(playername)
	local sel = ltool.playerinfos[playername].dbsel 
	if(sel ~= nil) then
		return ltool.playerinfos[playername].treeform.database.textlist[sel]
	end
	return nil
end

ltool.treeform = ltool.loadtreeform..ltool.header(1)..ltool.edit()

minetest.register_chatcommand("treeform",
{
	params = "",
	description = "Open L-system tree builder formular.",
	privs = {privs=false},
	func = function(player_name, param)
		local player = minetest.get_player_by_name(player_name)
		local formspec
--		if(ltool.playerinfos[player] == nil) then
			formspec = ltool.treeform
--[[		else
			local i = ltool.playerinfos[player]
			formspec = 
			"size[6,7]"..
			"field[0.2,-4;6,10;axiom;Axiom;"..i.axiom.."]"..
			"field[0.2,-3.4;6,10;rules_a;Rules set A;"..i.rules_a.."]"..
			"field[0.2,-2.7;6,10;rules_b;Rules set B;"..i.rules_b.."]"..
			"field[0.2,-2.1;6,10;rules_c;Rules set C;"..i.rules_c.."]"..
			"field[0.2,-1.5;6,10;rules_d;Rules set D;"..i.ruled_d.."]"..
			"field[0.2,-0.9;3,10;trunk;Trunk node name;"..i.trunk.."]"..
			"field[0.2,-0.3;3,10;leaves;Leaves node name;"..i.leaves.."]"..
			"field[0.2,0.3;3,10;leaves2;Secondary leaves node name;"..i.leaves2.."]"..
			"field[0.2,0.9;3,10;leaves2_chance;Secondary leaves chance;"..i.leaves2_chance.."]"..
			"field[0.2,1.5;3,10;fruit;Fruit node name;"..i.fruit.."]"..
			"field[0.2,2.1;3,10;fruit_chance;Fruit chance;"..i.fruit_chance.."]"..
		
			"field[3.2,-0.9;3,10;angle;Angle;"..i.angle.."]"..
			"field[3.2,-0.3;3,10;iterations;Iterations;"..i.iterations.."]"..
			"field[3.2,0.3;3,10;random_level;Randomness level;"..i.random_level.."]"..
			"field[3.2,0.9;3,10;trunk_type;Trunk type (single/double/crossed);"..i.trunk_type.."]"..
			"field[3.2,1.5;3,10;thin_branches;Thin branches? (true/false);"..i.thin_branches.."]"..
			"button[0.6,6.5;2,1;edit_save;Save]"..
		end
]]
		minetest.show_formspec(player_name, "ltool:treeform_edit", formspec)
	end
})

function ltool.dbsel_to_tree(dbsel, playername)
	return ltool.trees[ltool.playerinfos[playername].treeform.database.textlist[dbsel]]
end

function ltool.process_form(player,formname,fields)
	local playername = player:get_player_name()
	local seltree = ltool.get_selected_tree(playername)
	if(formname == "ltool:treeform_edit" or formname == "ltool:treeform_database" or formname == "ltool:treeform_plant" or formname == "ltool:treeform_cheat_sheet") then
		if fields.ltool_tab ~= nil then
			local tab = tonumber(fields.ltool_tab)
			local formspec, subformname, contents
			if(tab==1) then
				contents = ltool.edit()
				subformname = "edit"
			elseif(tab==2) then
				contents = ltool.database(ltool.playerinfos[playername].dbsel, playername)
				subformname = "database"
			elseif(tab==3) then
				if(ltool.number_of_trees > 0) then
					contents = ltool.plant(seltree)
				else
					contents = ltool.plant()
				end
				subformname = "plant"
			elseif(tab==4) then
				contents = ltool.cheat_sheet()
				subformname = "cheat_sheet"
			end
			formspec = ltool.loadtreeform..ltool.header(tab)..contents
			minetest.show_formspec(playername, "ltool:treeform_" .. subformname, formspec)
			return
		end
	end
	if(formname == "ltool:treeform_plant") then
		if(fields.plant_plant) then
			if(seltree ~= nil) then
				minetest.log("action","[ltool] Planting tree")
				local treedef = seltree.treedef

				local x,y,z = tonumber(fields.x), tonumber(fields.y), tonumber(fields.z)
				local tree_pos
				local fail = function()
					local formspec = "size[6,2;]label[0,0.2;Error: The coordinates must be numbers.]"..
					"button[2,1.5;2,1;okay;OK]"
					minetest.show_formspec(playername, "ltool:treeform_error_badplantfields", formspec)
				end
				if(fields.plantmode == "Absolute coordinates") then
					if(type(x)~="number" or type(y) ~= "number" or type(z) ~= "number") then
						fail()
						return
					end
					tree_pos = {x=fields.x, y=fields.y, z=fields.z}
				elseif(fields.plantmode == "Relative coordinates") then
					if(type(x)~="number" or type(y) ~= "number" or type(z) ~= "number") then
						fail()
						return
					end
					tree_pos = player:getpos()
					tree_pos.x = tree_pos.x + fields.x
					tree_pos.y = tree_pos.y + fields.y
					tree_pos.z = tree_pos.z + fields.z
				else
					minetest.log("error", "[ltool] fields.plantmode = "..tostring(fields.plantmode))
				end
	
				if(tonumber(fields.seed)~=nil) then
					treedef.seed = tonumber(fields.seed)
				end
	
				minetest.spawn_tree(tree_pos, treedef)
	
				treedef.seed = nil
			end
		elseif(fields.sapling) then
			if(seltree ~= nil) then
				local sapling = ItemStack("ltool:sapling")
				-- TODO: Copy the seed into the sapling, too.
				sapling:set_metadata(minetest.serialize(seltree.treedef))
				local leftover = player:get_inventory():add_item("main", sapling)
				-- TODO: Open error dialog if item could not be given to player
			end
		end
	elseif(formname == "ltool:treeform_edit") then
		if(fields.edit_save) then
			local param1, param2
			param1, param2 = ltool.evaluate_edit_fields(fields)
		
			if(param1 ~= nil) then
				local treedef = param1
				local name = param2
				ltool.add_tree(name, playername, treedef)
			else
				local formspec = "size[6,2;]label[0,0.2;Error: The tree definition is invalid.]"..
				"label[0,0.4;"..minetest.formspec_escape(param2).."]"..
				"button[2,1.5;2,1;okay;OK]"
				minetest.show_formspec(playername, "ltool:treeform_error_badtreedef", formspec)
			end
		end
	elseif(formname == "ltool:treeform_database") then
		if(fields.treelist) then
			local event = minetest.explode_textlist_event(fields.treelist)
			if(event.type == "CHG") then
				ltool.playerinfos[playername].dbsel = event.index
				local formspec = ltool.loadtreeform..ltool.header(2)..ltool.database(event.index, playername)
				minetest.show_formspec(playername, "ltool:treeform_database", formspec)
			end
		elseif(fields.database_copy) then
			if(seltree ~= nil) then
				if(ltool.playerinfos[playername] ~= nil) then
					local formspec = ltool.loadtreeform..ltool.header(1)..ltool.edit(seltree)
					minetest.show_formspec(playername, "ltool:treeform_edit", formspec)
				else
					-- TODO: fail
				end
			end
		elseif(fields.database_update) then
			local formspec = ltool.loadtreeform..ltool.header(2)..ltool.database(ltool.playerinfos[playername].dbsel, playername)
			minetest.show_formspec(playername, "ltool:treeform_database", formspec)

		elseif(fields.database_delete) then
			if(seltree ~= nil) then
				if(playername == seltree.author) then
					local remove_id = ltool.get_selected_tree_id(playername)
					if(remove_id ~= nil) then
						ltool.trees[remove_id] = nil
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
						local formspec = ltool.loadtreeform..ltool.header(2)..ltool.database(ltool.playerinfos[playername].dbsel, playername)
						minetest.show_formspec(playername, "ltool:treeform_database", formspec)
					else
						-- TODO: fail
					end
				else
					local formspec = "size[6,2;]label[0,0.2;Error: This tree is not your own. You may only delete your own trees.]"..
					"button[2,1.5;2,1;okay;OK]"
					minetest.show_formspec(playername, "ltool:treeform_error_delete", formspec)
				end
			end
		elseif(fields.database_rename) then
			if(seltree ~= nil) then
				if(playername == seltree.author) then
					local formspec = "field[newname;New name:;"..minetest.formspec_escape(seltree.name).."]"
					minetest.show_formspec(playername, "ltool:treeform_rename", formspec)
				else
					local formspec = "size[6,2;]label[0,0.2;Error: This tree is not your own. You may only rename your own trees.]"..
					"button[2,1.5;2,1;okay;OK]"
					minetest.show_formspec(playername, "ltool:treeform_error_rename", formspec)
				end
			end
		end
	elseif(formname == "ltool:treeform_rename") then
		if(fields.newname ~= "") then
			seltree.name = fields.newname
			local formspec = ltool.loadtreeform..ltool.header(2)..ltool.database(ltool.playerinfos[playername].dbsel, playername)
			minetest.show_formspec(playername, "ltool:treeform_database", formspec)
		else
			-- TODO: fail
		end
	elseif(formname == "ltool:treeform_error_badtreedef") then
		local formspec = ltool.loadtreeform..ltool.header(1)..ltool.edit()
		minetest.show_formspec(playername, "ltool:treeform_edit", formspec)
	elseif(formname == "ltool:treeform_error_badplantfields") then
		local formspec = ltool.loadtreeform..ltool.header(3)..ltool.plant(ltool.trees[ltool.playerinfos[playername].dbsel])
		minetest.show_formspec(playername, "ltool:treeform_plant", formspec)
	elseif(formname == "ltool:treeform_error_delete" or formname == "ltool:treeform_error_rename") then
		local formspec = ltool.loadtreeform..ltool.header(2)..ltool.database(ltool.playerinfos[playername].dbsel, playername)
		minetest.show_formspec(playername, "ltool:treeform_database", formspec)
	end
end

function ltool.leave(player)
	ltool.playerinfos[player:get_player_name()] = nil
end

function ltool.join(player)
	local infotable = {}
	infotable.dbsel = nil
	infotable.treeform = {}
	infotable.treeform.database = {}
	--[[ This table stores a mapping of the textlist IDs in the database formspec and the tree IDs.
	It is updated each time ltool.database is called. ]]
	infotable.treeform.database.textlist = nil
	ltool.playerinfos[player:get_player_name()] = infotable
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
