----------------------------------------------------------------------------------------------------
---------------------------------------- Nanu Script Tools -----------------------------------------
----------------------------------------------------------------------------------------------------
----																							----
----	This script is a collection of helper functions and basic objects for use throughout	----
----	my scripts. It includes functions that extend or correct CA functions and provides		----
----	tools that are typically unavailable in a lua environment								----
----																							----
----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------



Queue = {};

function Queue.new()
	return {first = 1, last = 0}
end

function Queue.add(self, value)
	local last = self.last + 1;
	self.last = last;
	self[last] = value;
end
function Queue.next(self)
	local first = self.first;
	if first > self.last then
		return nil;
	end
	local value = self[first];
	self[first] = nil;
	self.first = first + 1;
	out("first = "..self.first..", last = "..self.last);
	if self.first < self.last then
		out("next in queue = {"..self[self.first][1]..", "..self[self.first][2].."}");
	end
	out("returning {"..value[1]..", "..value[2].."}");
	return value;
end
function Queue.peek(self)
	return self[self.first];
end
function Queue.peekIndex(self, index)
	return self[index];
end
function Queue.toList(self)
	if self.first <= self.last then
		local list = {}
		local i = self.first;
		while i <= self.last do 
			table.insert(list, self[i]);
			i = i + 1;
		end
		return list;
	end
	return nil;
end

function split(string, pattern)
    local Table = {};
    for word in string.gmatch(string, '([^'..pattern..']+)') do
        table.insert(Table, word)
    end
    return Table
end



--CAs find_valid_spawn_location_for_character functions are incredibly helpful, but often fail, these functions ensure they don't (or at leasts makes it super unlikely that they will)
function get_coordinates_for_faction_by_region(region, faction, radius)
	
	local x, y = cm:find_valid_spawn_location_for_character_from_settlement(faction, region, false, true, radius);
	--out("x: "..x..", y: "..y);
	
	if x > 0 then
		return x, y
	end
	
    --if the above fails try by position instead
    return get_coordinates_for_faction_by_position(region:settlement():logical_position_x(), region:settlement():logical_position_y(), faction, radius)
    
end

function get_coordinates_for_faction_by_character(target_character, faction, radius)
	
	local x, y = cm:find_valid_spawn_location_for_character_from_character(faction, cm:char_lookup_str(target_character:command_queue_index()), true, radius);
	
	--out("x: "..x..", y: "..y);
	
    if x > 0 then
        return x, y;
    end
    
    --if the above fails try by position instead
    return get_coordinates_for_faction_by_position(target_character:logical_position_x(), target_character:logical_position_y(), faction, radius)
end

--last attempt, will change xpos and ypos each iteration to try to avoid repeat failures
function get_coordinates_for_faction_by_position(xpos, ypos, faction, radius)
    local x, y = -1, -1;
    local x_mod, y_mod = 1, 0
    
    local search_state = 1;
    local column = 1;
    local row = 0;
    
    
--           y
--           |
--           |
--    16 15 14 13 12
--    17  4  3  2 11
-- -- 18  5  0  1 10 --- x
--    19  6  7  8  9
--    20 21 22 23 24
--           |
--           |

    for i = 1, 24 do
        x, y = cm:find_valid_spawn_location_for_character_from_position(faction, xpos + x_mod, ypos + y_mod, true, radius);
		--out("x: "..x..", y: "..y);
        if x > 0 then
            return x, y;
        end
        
        --Move Right
        if search_state == 0 then
            x_mod = x_mod + 1;
            if x_mod > y_mod * -1 then
                search_state = 1;
            end 
        --Move Up
        elseif search_state == 1 then
            y_mod = y_mod + 1;
            if y_mod >= x_mod then
                search_state = 2;
            end 
        --Move Left
        elseif search_state == 2 then
            x_mod = x_mod - 1;
            if x_mod <= y_mod * -1 then
                search_state = 3;
            end 
        --Move Down
        elseif search_state == 3 then
            y_mod = y_mod - 1;
            if y_mod <= x_mod then
                search_state = 0;
            end 
        else end 
        
		--out("x: "..x_mod..", y: "..y_mod);
    end
end

function get_distance(x1, y1, x2, y2)
	return math.sqrt(distance_squared(x1, y1, x2, y2));
end

function distance_squared(x1, y1, x2, y2)
	return math.pow((x1-x2), 2) + math.pow((y1 - y2), 2);
end

function table.empty (self)
    for _, _ in pairs(self) do
        return false
    end
    return true
end

function table.random (self)
    local new_table = {};
    for v, k in pairs(self) do
        table.insert(new_table, v);
    end
    return new_table[math.random(1, #new_table)];
end

function table.length (self)
    local i = 0
    for v, k in pairs(self) do
        i = i + 1;
    end
    return i;
end

--helper functions, leave these alone too 
function table.insert_if_absent (self, value)
    if not table.check_value(self, value) then
        table.insert(self, #self + 1, value);
    end
end

function table.check_value (self, value)
    for _, k in pairs(self) do
        if k == value then
            return true;
        end 
    end
    return false;
end





