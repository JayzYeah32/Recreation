
local bl2 = 16
local base = 2 ^ bl2
local bitb = base - 1
local nb10 = 9999999999 -- pow(10, floor(log10(2 ^ 52) / 2 ^ bl2)) - 1

local band = bit32.band
local bor = bit32.bor
local bxor = bit32.bxor
local lshift = bit32.lshift
local rshift = bit32.rshift

local byte = string.byte
local rep = string.rep

local concat = table.concat
local insert = table.insert

local floor = math.floor
local log10 = math.log10
local max = math.max
local min = math.min

local mtable = nil

local s_lshift, b_lshift, b_rshift, b_add, b_sub, b_mul, b_div, b_mod

local function b_new(number, ignore)
	if type(number) == "number" then
		local out = {sign = number < 0 and not ignore and "-" or "+"}
		number = number < 0 and -number or number
		while number > 0 do
			insert(out, band(number, bitb))
			number = floor(number / base)
		end
		return setmetatable(out, mtable)
	elseif type(number) == "table" then
		local out = {sign = ignore and "+" or number.sign}
		for i=1,#number do
			insert(out, number[i])
		end
		return setmetatable(out, mtable)
	elseif type(number) == "string" then
		local out = {sign = "+"}
		for i=1,number:len() do
			out = b_add(s_lshift(out, 8), b_new(byte(number:sub(i, i))))
		end
		return setmetatable(out, mtable)
	end
	return setmetatable({sign = "+"}, mtable)
end

local function b_tonumber(bigint)
	local out = 0
	local pow = 1
	for i=1,#bigint do
		out = out + bigint[i] * pow
		pow = pow * base
	end
	return out
end

local function b_tofnumber(bigint)
	return bigint.sign:gsub("+", "") .. ("%.f"):format(b_tonumber(bigint))
end

--[[local function b_tolnumber(bigint)
	local out = {}
	local function add(t1, s2)
		local high = max(#t1, s2:len())
		local carry = 0
		for i=1,high do
			local char = s2:sub(i, i)
			local result = (t1[i] or 0) + (tonumber(char == "" and 0 or char)) + carry
			carry = result > 9 and 1 or 0
			t1[i] = result - carry * 10
		end
		if carry ~= 0 then
			insert(t1, carry)
		end
		return t1
	end
	local function mul(s1, s2)
		local out = ""
		for i=1,s2:len() do
			if s2:sub(i, i) == "0" then
				continue
			end
			local carry = 0
			local out2 = {}
			for i2=2,i do
				insert(out2, 0)
			end
			for i2=1,s1:len() do
				local result = tonumber(s1:sub(i2, i2)) * tonumber(s2:sub(i, i)) + carry
				carry = result > 9 and floor(result / 10) or 0
				insert(out2, result - carry * 10)
			end
			if carry ~= 0 then
				insert(out2, carry)
			end
			out = concat(add(out2, out))
		end
		return out
	end
	local pow = "1"
	local out = {}
	for i=1,#bigint do
		out = add(out, mul(reverse(tostring(bigint[i])), pow))
		pow = mul(pow, reverse(tostring(base)))
	end
	return bigint.sign == "-" and "-" or "+" .. reverse(concat(out))
end]]

local function b_tolnumber(bigint)
	local bigint = b_new(bigint)
	local out = {}
	local function add(t1, t2)
		local high = max(#t1, #t2)
		local carry = 0
		for i=1,high do
			local result = (t1[i] or 0) + (t2[i] or 0) + carry
			carry = result > nb10 and 1 or 0
			t1[i] = result - carry * (nb10 + 1)
		end
		if carry ~= 0 then
			insert(t1, carry)
		end
		return t1
	end
	local function mul(t1, t2)
		local out = {}
		for i=1,#t2 do
			if t2[i] == 0 then
				continue
			end
			local carry = 0
			local out2 = {}
			for i2=2,i do
				insert(out2, 0)
			end
			for i2=1,#t1 do
				local result = t1[i2] * t2[i] + carry
				carry = result > nb10 and floor(result / (nb10 + 1)) or 0
				insert(out2, result - (carry > 0 and carry * (nb10 + 1) or 0))
			end
			if carry ~= 0 then
				insert(out2, carry)
			end
			out = add(out, out2)
		end
		return out
	end
	local pow = {1}
	for i=1,#bigint do
		out = add(out, mul({bigint[i]}, pow))
		pow = mul(pow, {base})
	end
	local out2 = {}
	for i=#out,1,-1 do
		insert(out2, out[i])
	end
	local len = log10(nb10 + 1)
	for i=1,#out2 do
		out2[i] = ("%.f"):format(out2[i])
		if i ~= 1 then
			out2[i] = rep("0", len - out2[i]:len()) .. out2[i]
		end
	end
	return bigint.sign:gsub("+", "") .. concat(out2)
end

local function b_isnil(bigint)
	local bigint = b_new(bigint)
	return bigint == nil or bigint == 0 or #bigint == 0 or (bigint[1] == 0 and #bigint == 1)
end

local function check(bigint)
	return b_isnil(bigint) and b_new() or bigint
end

local function b_equal(big1, big2, ignore)
	local big1 = b_new(big1)
	local big2 = b_new(big2)
	if b_isnil(big1) and b_isnil(big2) then
		return true
	elseif b_isnil(big1) ~= b_isnil(big2) then
		return false
	elseif not ignore and big1.sign ~= big2.sign then
		return false
	elseif #big1 ~= #big2 then
		return false
	end
	
	for i=1,#big1 do
		if big1[i] ~= big2[i] then
			return false
		end
	end
	return true
end

local function b_greater(big1, big2, ignore)
	local big1 = b_new(big1)
	local big2 = b_new(big2)
	local switch = (not ignore and big1.sign == "-" and big2.sign == "-")
	if big1.sign ~= big2.sign and not ignore then
		return big1.sign == "+"
	elseif #big1 ~= #big2 then
		return switch ~= (#big1 > #big2)
	elseif b_equal(big1, big2, ignore) then
		return false
	end
	for i=#big1,1,-1 do
		if big1[i] ~= big2[i] then
			return switch ~= (big1[i] > big2[i])
		end
	end
end

local function b_lesser(big1, big2, ignore)
	local big1 = b_new(big1, ignore)
	local big2 = b_new(big2, ignore)
	if b_equal(big1, big2, ignore) then
		return false
	end
	return not b_greater(big1, big2, ignore)
end

function s_lshift(big1, num2)
	local big1 = b_new(big1)
	if b_isnil(big1) then
		return b_new()
	end
	local prediv = floor(num2 / bl2)
	local premod = num2 - prediv * bl2
	local out = b_new()
	for i=1,prediv do
		insert(out, 0)
	end
	if premod == 0 then
		for i=1,#big1 do
			insert(out, big1[i])
		end
	else
		local carry = 0
		for i=1,#big1 do
			local result = lshift(big1[i], premod)
			insert(out, band(result, bitb) + carry)
			carry = rshift(result, bl2)
		end
		if carry ~= 0 then
			insert(out, carry)
		end
	end
	return check(out)
end

local function s_rshift(big1, num2)
	local big1 = b_new(big1)
	if b_isnil(big1) then
		return b_new()
	end
	local out = s_lshift(big1, bl2 - num2 % bl2)
	local prediv = floor(num2 / bl2)
	for i=1,#out do
		out[i] = out[i + 1 + prediv]
	end
	return check(out)
end

function b_lshift(big1, big2)
	local big1 = b_new(big1)
	local big2 = b_new(big2)
	if big2.sign == "-" then
		big2.sign = "+"
		b_rshift(big1, big2)
	end
	if b_isnil(big1) then
		return b_new()
	elseif b_isnil(big2) then
		return big1
	end
	local quotient, remainder = b_div(big2, bl2)
	quotient = b_add(quotient, 1)
	local out = b_new()
	local i = b_new(1)
	while b_greater(quotient, i) do
		insert(out, 0)
		i = b_add(i, 1)
	end
	for i=1,#big1 do
		insert(out, big1[i])
	end
	return check(s_lshift(out, b_tonumber(remainder)))
end

function b_rshift(big1, big2)
	local big1 = b_new(big1)
	local big2 = b_new(big2)
	if big2.sign == "-" then
		big2.sign = "+"
		b_lshift(big1, big2)
	end
	if b_isnil(big1) then
		return b_new()
	elseif b_isnil(big2) then
		return big1
	end
	local quotient, remainder = b_div(big2, bl2)
	local out = s_lshift(big1, bl2 - b_tonumber(remainder))
	for i=1,#out do
		out[i] = out[i + 1 + b_tonumber(quotient)]
	end
	return check(out)
end

function b_add(big1, big2)
	local big1 = b_new(big1)
	local big2 = b_new(big2)
	
	if big1.sign ~= big2.sign then
		if b_equal(big1, big2, true) then
			return b_new()
		elseif b_greater(big2, big1, true) then
			big1.sign = big1.sign == "+" and "-" or "+"
			return b_sub(big2, big1)
		else
			big2.sign = big1.sign
			return b_sub(big1, big2)
		end
	end
	
	if b_isnil(big1) then
		return big2
	elseif b_isnil(big2) then
		return big1
	end
	local out = b_new()
	local carry = 0
	local high = max(#big1, #big2)
	for i=1,high do
		local result = (big1[i] or 0) + (big2[i] or 0) + carry
		insert(out, band(result, bitb))
		carry = rshift(result, bl2)
	end
	if carry ~= 0 then
		insert(out, carry)
	end
	out.sign = big1.sign
	return check(out)
end

function b_sub(big1, big2)
	local big1 = b_new(big1)
	local big2 = b_new(big2)
	
	if big1.sign == big2.sign then
		if b_equal(big1, big2, true) then
			return b_new()
		elseif b_greater(big2, big1, true) then
			big1.sign = big1.sign == "+" and "-" or "+"
			big2.sign = big1.sign
			return b_sub(big2, big1)
		end
	elseif big1.sign ~= big2.sign then
		big2.sign = big1.sign
		return b_add(big1, big2)
	end
	
	if b_isnil(big2) then
		return big1
	end
	local out = b_new()
	local carry = 0
	local high = max(#big1, #big2)
	for i=1,high do
		local result = (big1[i] or 0) - (big2[i] or 0) - carry
		insert(out, band(result, bitb))
		carry = result < 0 and 1 or 0
	end
	if out[#out] == 0 then
		out[#out] = nil
	end
	out.sign = big1.sign
	return check(out)
end

function b_mul(big1, big2, big3) -- big3 = cap to help with root
	local big1 = b_new(big1)
	local big2 = b_new(big2)
	local big3 = b_new(big3)
	if b_isnil(big1) or b_isnil(big2) then
		return b_new()
	end
	local out = b_new()
	for i=1,#big2 do
		if big2[i] == 0 then
			continue
		end
		local carry = 0
		local out2 = b_new()
		for i2=2,i do
			insert(out2, 0)
		end
		for i2=1,#big1 do
			local result = big1[i2] * big2[i] + carry
			insert(out2, band(result, bitb))
			carry = rshift(result, bl2)
		end
		if carry ~= 0 then
			insert(out2, carry)
		end
		out = b_add(out, out2)
		if not b_isnil(big3) and b_greater(out, big3) then
			return nil
		end
	end
	out.sign = big1.sign == big2.sign and "+" or "-"
	return check(out)
end

function b_div(big1, big2)
	local big1 = b_new(big1)
	local big3 = b_new(big2)
	local sign = big1.sign == big3.sign and "+" or "-"
	big1.sign = "+"
	big3.sign = "+"
	assert(not b_isnil(big2), "Cannot divide by 0!")
	if b_isnil(big1) then
		return b_new()
	end
	local count = b_new(1)
	local out = b_new()
	while #big3 < #big1 do
		big3 = s_lshift(big3, bl2)
		count = s_lshift(count, bl2)
	end
	while b_lesser(big3, big1) do
		big3 = s_lshift(big3, 1)
		count = s_lshift(count, 1)
	end
	while not b_lesser(big3, big2, true) and not b_isnil(count) do
		if b_lesser(big3, big1) then
			big1 = b_sub(big1, big3)
			out = b_add(out, count)
		elseif b_equal(big3, big1) then
			big1 = b_sub(big1, big3)
			out = b_add(out, count)
			break
		end
		big3 = s_rshift(big3, 1)
		count = s_rshift(count, 1)
	end
	out.sign = sign
	return check(out), check(big1), check(b_new(big2, true))
end

function b_mod(big1, big2)
	local big1 = b_new(big1)
	local big2 = b_new(big2)
	if b_lesser(big1, big2) then
		return b_new(big1)
	elseif b_equal(big1, big2) or b_equal(big1, b_new()) or b_equal(big2, 1) then
		return b_new()
	end
	local _, remainder = b_div(big1, big2)
	return remainder
end

local function b_pow(big1, big2, big3) -- big3 = cap used for finding root
	local big1 = b_new(big1)
	local big3 = b_new(big3)
	if b_isnil(big1) then
		return b_new()
	end
	local big2 = b_new(big2)
	if b_isnil(big2) then
		return b_new(1)
	end
	if big2.sign == "-" then
		big2.sign = "+"
		local pow = b_pow(big1, big2, big3)
		if pow == nil then
			return nil
		end
		return b_new(), b_new(1), pow
	end
	if b_equal(big2, 1) then
		return big1
	elseif b_equal(big2, 2) then
		return b_mul(big1, big1, big3)
	end
	local quotient = s_rshift(big2, 1)
	local remainder = band(big2[1] or 0, 1)
	local pow = b_pow(big1, quotient, big3)
	if pow == nil then
		return nil
	end
	if b_equal(remainder, 1) then
		local result = b_mul(pow, pow, big3)
		if result == nil then
			return nil
		end
		return b_mul(result, big1, big3)
	else
		return b_mul(pow, pow, big3)
	end
end

local function b_powmod(big1, big2, big3)
	local big1 = b_new(big1)
	local big2 = b_new(big2)
	local big3 = b_new(big3)
	if b_equal(big2, 1) then
		return b_mod(big1, big3)
	end
	local num = b_powmod(big1, s_rshift(big2, 1), big3)
	num = b_mod(b_mul(num, num), big3)
	if band(big2[1] or 0, 1) == 0 then
		return num
	else
		return b_mod(b_mul(num, big1), big3)
	end
end

local function b_root(big1, big2)
	local big1 = b_new(big1)
	local big2 = b_new(big2, true)
	if b_isnil(big1) or b_isnil(big2) then
		return b_new(), b_new()
	end
	local out = b_new()
	local sign = band(big2[1] or 0, 1) == 1 and big1.sign or "+"
	big1.sign = "+"
	
	local upper = b_new(big1)
	local lower = b_new()
	local prev = b_new()
	local iter = b_new()
	while true do
		if #upper - #lower >= 2 then
			out = b_rshift(upper, b_mul(bl2, floor((#upper + #lower) / 2)))
		else
			out = s_rshift(b_add(upper, lower), 1)
		end
		local pow = b_pow(out, big2, big1)
		if pow == nil then
			upper = out
		else
			if b_equal(prev, out) or b_equal(pow, big1) then
				out.sign = sign
				return out, iter
			elseif b_greater(pow, big1) then
				upper = out
			else
				lower = out
			end
		end
		iter = b_add(iter, 1)
		prev = out
	end
end

--[[local function b_fastexp(big1, big2, big3)
	local big1 = b_new(big1)
	local big2 = b_new(big2)
	local big3 = b_new(big3)
	local out = b_new(1)
	if band(big2[1] or 0, 1) == 1 then
		out = b_new(big1)
	end
	while not b_equal(big2, 0) do
		big2 = s_rshift(big2, 1)
		big1 = b_mod(b_mul(big1, big1), big3)
		if band(big2[1] or 0, 1) == 1 then
			out = b_mod(b_mul(out, big1), big3)
		end
	end
	return out
end]]

mtable = {
	__add = b_add,
	__sub = b_sub,
	__mul = b_mul,
	__div = b_div,
	__mod = b_mod,
	__pow = b_pow,
	__eq = b_equal,
	__lt = b_lesser,
	__le = function(this, value)
		return not b_greater(this, value)
	end,
	__tostring = b_tolnumber,
}

return {
	new = b_new,
	add = b_add,
	sub = b_sub,
	mul = b_mul,
	div = b_div,
	pow = b_pow,
	mod = b_mod,
	powmod = b_powmod,
	
	equal = b_equal,
	gt = b_greater,
	ge = function(big1, big2)
		return b_equal(big1, big2) or b_greater(big1, big2)
	end,
	lt = b_lesser,
	le = function(big1, big2)
		return b_greater(big1, big2)
	end,
	notequal = function(big1, big2)
		return not b_equal(big1, big2)
	end,
	isnil = b_isnil,
	
	band = function(big1, big2)
		local out = b_new()
		for i=1,min(#big1, #big2) do
			out[i] = band(big1[i], big2[i])
		end
		return big1
	end,
	bnot = function(big1)
		local big1 = b_new(big1)
		for i=1,#big1 do
			big1[i] = bxor(big1[i], bitb)
		end
		return big1
	end,
	bor = function(big1, big2)
		local out = b_new()
		for i=1,max(#big1, #big2) do
			out[i] = bor(big1[i] or 0, big2[i] or 0)
		end
		return big1
	end,
	bxor = function(big1, big2)
		local out = b_new()
		for i=1,max(#big1, #big2) do
			out[i] = bxor(big1[i] or 0, big2[i] or 0)
		end
		return big1
	end,
	lshift = b_lshift,
	rshift = b_rshift,
	
	tonumber = b_tonumber,
}
