ltool = {}

ltool.playerinfos = {}
ltool.trees = {}
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

function ltool.add_tree(name, author, treedef)
	table.insert(ltool.trees, {name = name, author = author, treedef = treedef})
end

do
	local filepath = minetest.get_worldpath().."/ltool.mt"
	local file = io.open(filepath, "r")
	if(file) then
		local string = file:read()
		io.close(file)
		if(string ~= nil) then
			local savetable = minetest.deserialize(string)
			if(savetable.trees ~= nil) then
				ltool.trees = savetable.trees
			end
		end
		minetest.log("action", "[ltool] Tree data loaded from "..filepath..".")
	else
	--[=[
		--[[ add some example trees ]]
		ltool.add_tree("Apple Tree", nil,
		{
			axiom="FFFFFAFFBF",
			rules_a="[&&&FFFFF&&FFFF][&&&++++FFFFF&&FFFF][&&&----FFFFF&&FFFF]",
			rules_b="[&&&++FFFFF&&FFFF][&&&--FFFFF&&FFFF][&&&------FFFFF&&FFFF]",
			trunk="default:tree",
			leaves="default:leaves",
			angle=30,
			iterations=2,
			random_level=0,
			trunk_type="single",
			thin_branches=true,
			fruit_chance=10,
			fruit="default:apple"
		})
		ltool.add_tree("Example tree 1", "Wuzzy", {})
		ltool.add_tree("Special []<>,; character tree", "Wuzzy", {})
	]=]
	end
end

ltool.seed = os.time()

ltool.loadtreeform = "size[6,7]"

function ltool.header(index)
	return "tabheader[0,0;ltool_tab;Edit,Database,Plant;"..tostring(index)..";true;false]"
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
	"field[0.2,0.9;3,10;leaves2_chance;Secondary leaves chance;"..s(treedef.leaves2_chance).."]"..
	"field[0.2,1.5;3,10;fruit;Fruit node name;"..s(treedef.fruit).."]"..
	"field[0.2,2.1;3,10;fruit_chance;Fruit chance;"..s(treedef.fruit_chance).."]"..

	"field[3.2,-0.9;3,10;angle;Angle (in degrees);"..s(treedef.angle).."]"..
	"field[3.2,-0.3;3,10;iterations;Iterations;"..s(treedef.iterations).."]"..
	"field[3.2,0.3;3,10;random_level;Randomness level;"..s(treedef.random_level).."]"..
	"field[3.2,0.9;3,10;trunk_type;Trunk type (single/double/crossed);"..s(treedef.trunk_type).."]"..
	"field[3.2,1.5;3,10;thin_branches;Thin branches? (true/false);"..s(treedef.thin_branches).."]"..
	"field[3.2,2.1;3,10;name;Name;"..s(name).."]"..
	"button[0,6.5;2,1;edit_okay;Plant]"..
	"button[2.1,6.5;2,1;edit_save;Save]"
end

function ltool.database(index)
	local treestr = ltool.get_tree_names(index)
	if(treestr ~= nil) then
		return ""..
		"textlist[0,0;5,6;treelist;"..treestr..";"..tostring(index)..";false]"..
		"button[0,6.5;2,1;database_copy;Copy to editor]"..
		"button[2.1,6.5;2,1;database_update;Reload]"
	else
		return "label[0,0;The tree database is empty.]"..
		"button[2.1,6.5;2,1;database_update;Reload]"
	end
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
	treedef.iterations = tonumber(fields.iterations)
	treedef.random_level = tonumber(fields.random_level)
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

function ltool.plant()
	return ""..
	"label[-0.2,-0.5;Selected: <insert tree here>]"..
--	"dropdown[0,0.3;5;plantmode;Absolute coordinates,Relative coordinates,Distance to view;1]"..
--	"field[0.2,-2.7;6,10;x;x;]"..
--	"field[0.2,-2.1;6,10;y;y;]"..
--	"field[0.2,-1.5;6,10;z;z;]"..
	"field[0.2,0;6,10;seed;Seed;"..ltool.seed.."]"..
	"button[0,6.5;2,1;plant_plant;Plant]"
end


function ltool.get_tree_names(index)
	local string = ""
	if(#ltool.trees == 0) then
		return nil
	end
	for t=1,#ltool.trees do
		string = string .. minetest.formspec_escape(ltool.trees[t].name)
		if(t < #ltool.trees) then
			string = string .. ","
		end
	end
	return string
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
			"button[0,6.5;2,1;edit_okay;Plant]"..
			"button[2.1,6.5;2,1;edit_save;Save]"..
		end
]]
		minetest.show_formspec(player_name, "ltool:treeform", formspec)
	end
})

function ltool.process_form(player,formname,fields)
	local playername = player:get_player_name()
	if(formname == "ltool:treeform") then
		if fields.ltool_tab ~= nil then
			local tab = tonumber(fields.ltool_tab)
			local formspec
			if(tab==1) then
				formspec = ltool.loadtreeform..ltool.header(1)..ltool.edit()
			elseif(tab==2) then
				formspec = ltool.loadtreeform..ltool.header(2)..ltool.database(ltool.playerinfos[playername].dbsel)
			elseif(tab==3) then
				formspec = ltool.loadtreeform..ltool.header(3)..ltool.plant()
			end
			minetest.show_formspec(playername, "ltool:treeform", formspec)
			return
		end
			
		if(fields.edit_okay or fields.plant_plant) then
			minetest.log("action","ltool: Planting tree")
			fields.angle = tonumber(fields.angle)
			fields.iterations = tonumber(fields.iterations)
			fields.random_level = tonumber(fields.random_level)
			if(fields.thin_branches == "true") then
				fields.thin_branches = true
			elseif(fields.thin_branches == "false") then
				fields.thin_branches = false
			else
				return
			end
			fields.seed = tonumber(fields.seed)
	
			local tree_pos = {x=0,y=0,z=0}
			tree_pos = player:getpos()
			tree_pos.x = tree_pos.x + 5


			minetest.spawn_tree(tree_pos, fields)
		elseif(fields.edit_save) then
			local param1, param2
			param1, param2 = ltool.evaluate_edit_fields(fields)
		
			if(treedef ~= nil) then
				local treedef = param1
				local name = param2
				ltool.add_tree(name, playername, treedef)
			else
				local formspec = "size[6,2;]label[0,0.2;Error: The tree definition is invalid.]"..
				"label[0,0.4;"..minetest.formspec_escape(param2).."]"..
				"button[2,1.5;2,1;okay;OK]"
				minetest.show_formspec(playername, "ltool:treeform_error_badtreedef", formspec)
			end
		elseif(fields.treelist) then
			local event = minetest.explode_textlist_event(fields.treelist)
			if(event.type == "CHG") then
				ltool.playerinfos[playername].dbsel = event.index
				local formspec = ltool.loadtreeform..ltool.header(2)..ltool.database(event.index)
				minetest.show_formspec(playername, "ltool:treeform", formspec)
			end
		elseif(fields.database_copy) then
			if(ltool.playerinfos[playername] ~= nil) then
				sel = ltool.playerinfos[playername].dbsel
			else
				sel = 1
			end
			local formspec = ltool.loadtreeform..ltool.header(1)..ltool.edit(ltool.trees[sel])
			minetest.show_formspec(playername, "ltool:treeform", formspec)
		elseif(fields.database_update) then
			local formspec = ltool.loadtreeform..ltool.header(2)..ltool.database(ltool.playerinfos[playername].dbsel)
			minetest.show_formspec(playername, "ltool:treeform", formspec)
		end
	elseif(formname == "ltool:treeform_error_badtreedef") then
		local formspec = ltool.loadtreeform..ltool.header(1)..ltool.edit()
		minetest.show_formspec(playername, "ltool:treeform", formspec)
	end
end

function ltool.leave(player)
	ltool.playerinfos[player:get_player_name()] = nil
end

function ltool.join(player)
	ltool.playerinfos[player:get_player_name()] = { dbsel = 1 }
end

function ltool.save_to_file()
	local savetable = {}
	savetable.trees = ltool.trees
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
