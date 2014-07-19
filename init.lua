ltool = {}

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

ltool.seed = os.time()

ltool.loadtreeform = "size[6,7]"

function ltool.header(index)
	return "tabheader[0,0;ltool_tab;Edit,Database,Plant;"..tostring(index)..";true;false]"
end

function ltool.edit(treedef)
	if(treedef==nil) then
		treedef = ltool.emptytreedef
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

	"field[3.2,-0.9;3,10;angle;Angle;"..s(treedef.angle).."]"..
	"field[3.2,-0.3;3,10;iterations;Iterations;"..s(treedef.iterations).."]"..
	"field[3.2,0.3;3,10;random_level;Randomness level;"..s(treedef.random_level).."]"..
	"field[3.2,0.9;3,10;trunk_type;Trunk type (single/double/crossed);"..s(treedef.trunk_type).."]"..
	"field[3.2,1.5;3,10;thin_branches;Thin branches? (true/false);"..s(treedef.thin_branches).."]"..
	"button[0,6.5;2,1;edit_okay;Plant]"..
-- TODO: implement saving and loading
	"button[2.1,6.5;2,1;edit_save;Save]"
end

function ltool.database()
	local treestr = ltool.get_tree_names()
	return ""..
	"textlist[0,0;5,6;treelist;"..treestr..";1;false]"..
	"button[0,6.5;2,1;database_select;Select]"..
	"button[2.1,6.5;2,1;database_copy;Copy to editor]"..
	"button[4.2,6.5;2,1;database_update;Update list]"
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

function ltool.add_tree(name, author, treedef)
	table.insert(ltool.trees, {name = name, author = author, treedef = treedef})
end

function ltool.get_tree_names()
	local string = ""
	for t=1,#ltool.trees do
		string = string .. minetest.formspec_escape(ltool.trees[t].name)
		if(t < #ltool.trees) then
			string = string .. ","
		end
	end
	return string
end

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
	if(formname == "ltool:treeform") then
		if fields.ltool_tab ~= nil then
			local tab = tonumber(fields.ltool_tab)
			local formspec
			if(tab==1) then
				formspec = ltool.loadtreeform..ltool.header(1)..ltool.edit()
			elseif(tab==2) then
				formspec = ltool.loadtreeform..ltool.header(2)..ltool.database()
			elseif(tab==3) then
				formspec = ltool.loadtreeform..ltool.header(3)..ltool.plant()
			end
			minetest.show_formspec(player:get_player_name(), "ltool:treeform", formspec)
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


		elseif(fields.database_copy) then
--			if(fields.treelist ~= nil) then
--				local sel = tonumber(fields.treelist)
				local sel = 1
				local formspec = ltool.loadtreeform..ltool.header(1)..ltool.edit(ltool.trees[sel].treedef)
				minetest.show_formspec(player:get_player_name(), "ltool:treeform", formspec)
--			end
		elseif(fields.database_select) then
			
		end
	elseif(formname == "ltool:loadtreeform") then

	end
end

function ltool.leave(player)
	ltool.playerinfos[player] = nil
end

minetest.register_on_player_receive_fields(ltool.process_form)

minetest.register_on_leaveplayer(ltool.leave)
