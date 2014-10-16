# API documentation
The L-System Tree Utility provides a set of simple functions to mess around with the tree database, generate trees from saplings and more.



## Data structures
### `treedef`
This is identical to the `treedef` parameter of `minetest.spawn_tree`.

### `tree`
A `tree` is the basic data structure. It is basically a wrapper around `treedef`, with some additional fields relevant for the L-System-Tree-Utility, which are listed here:

#### `tree_id`
A tree ID, an identifier of a `tree`. This is an unique number. Many functions require a tree ID.

No identifier is used twice, once an identifier is taken, it won’t be occupied again, even if the `tree` occupying the slot has been deleted.

#### `name`
An unique name of the tree, assigned by the user.

#### `author`
The name of the player who created the `tree`. The author is also the “owner” of the `tree` and is the only one who can edit it in the mod.



## Functions
### `ltool.get_tree_ids`
Returns a sorted table containing all tree IDs.

#### Parameters
None.

#### Return value
A sorted table containing all tree IDs, sorted by ID.



### `ltool.add_tree(name, author, treedef)`
Adds a tree to the tree table.

#### Parameters
* `name`: The tree’s name.
* `author`: The author’s / owners’ name
* `treedef`: The full tree definition, see lua_api.txt

#### Return value
The tree ID of the new tree.



### `ltool.remove_tree(tree_id)`
Removes a tree from the tree database.

#### Parameter
* `tree_id`: ID of the tree to be removed

#### Return value
Always `nil`.


### `ltool.rename_tree(tree_id, new_name)`
Renames a tree in the database

#### Parameters
* `tree_id`: ID of the tree to be renamed
* `new_name`: The name of the tree

#### Return value
Always `nil`.



### `ltool.copy_tree(tree_id)`
Creates a copy of a tree in the database.

#### Parameter
* `tree_id`: ID of the tree to be copied

#### Return value
The ID of the copy on success,
`false` on failure (tree does not exist).



### `ltool.generate_sapling(tree_id, seed)`
Generates a sapling as an `ItemStack` to mess around later with.

#### Parameter
* `tree_id`: ID of tree the sapling will grow
* `seed`: Seed of the tree the sapling will grow (optional, can be nil)
	
#### Return value
An `ItemStack` which contains one sapling of the specified `tree`, on success.
Returns `false` on failure (happens if tree does not exist).



### `ltool.give_sapling(tree_id, seed, player_name, ignore_priv)`
Gives a L-system tree sapling to a player.

#### Parameters
 * `tree_id`: ID of tree the sapling will grow
 * `seed`: Seed of the tree (optional; can be nil)
 * `playername`: name of the player to which
 * `ignore_priv`: if `true`, player’s `lplant` privilige is not checked (optional argument; default: `false`)

#### Return value
It depends:

* `true` on success
* `false, 1` if player does not have `lplant` privilege
* `false, 2` if player’s inventory is full
* `false, 3` if `tree` does not exist



### `ltool.plant_tree(tree_id, pos)`
Plants a tree as the specified position.

#### Parameters
* `tree_id`: ID of tree to be planted
* `pos`: Position of tree, in the format `{x=?, y=?, z=?}`

#### Return value
`false` on failure, `nil` otherwise.



### `ltool.show_treeform(playername)`
Shows the main tree formular to the given player, starting with the "Edit" tab.

#### Parameters
* `playername`: Name of the player to whom the formspec should be shown to

#### Return value
Always `nil.`
