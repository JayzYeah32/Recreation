
local bxor = bit32.bxor

local byte = string.byte
local char = string.char
local rep = string.rep

local sboxh = ([[637C777BF26B6FC53001672BFED7AB76CA82C97DFA5947F0ADD4A2AF9CA47
2C0B7FD9326363FF7CC34A5E5F171D8311504C723C31896059A071280E2EB27B27509832C1A1B6
E5AA0523BD6B329E32F8453D100ED20FCB15B6ACBBE394A4C58CFD0EFAAFB434D338545F9027F5
03C9FA851A3408F929D38F5BCB6DA2110FFF3D2CD0C13EC5F974417C4A77E3D645D197360814FD
C222A908846EEB814DE5E0BDBE0323A0A4906245CC2D3AC629195E479E7C8376D8DD54EA96C56F
4EA657AAE08BA78252E1CA6B4C6E8DD741F4BBD8B8A703EB5664803F60E613557B986C11D9EE1F
8981169D98E949B1E87E9CE5528DF8CA1890DBFE6426841992D0FB054BB16]]):gsub("[^0-9A-F]", "")

local sbox = {}
local isbox = {}
for i=1,256 do
	sbox[i] = tonumber(sboxh:sub(i * 2 - 1, i * 2), 16)
	isbox[sbox[i] + 1] = i - 1
end

local exp = {}
local log = {}
local a = 1

for i=0,255 do
	exp[i] = a
	log[a] = i
	a = bxor(a * 2, a)
	a = a > 255 and bxor(a, 283) or a
end

local function gf_mul(op1, op2)
	if op1 == 0 or op2 == 0 then
		return 0
	end

	local exponent = log[op1] + log[op2]
	return exp[exponent - (exponent > 255 and 255 or 0)]
end

local function rcon(index)
	return index > 1 and (rcon(index - 1) < 128 and 2 * rcon(index - 1) or
		rcon(index - 1) >= 128 and bxor(2 * rcon(index - 1), 283)) or index
end

local function expand_key(key, count)
	local words = {}
	local k_words = key:len() / 4
	for i=1,k_words do
		words[i] = {byte(key, i * 4 - 3, i * 4)}
	end

	for i=k_words + 1,count do
		local tmp = words[i - 1]
		if i % k_words == 1 then
			tmp = {bxor(sbox[tmp[2] + 1], rcon(math.floor(i / k_words))),
				sbox[tmp[3] + 1], sbox[tmp[4] + 1], sbox[tmp[1] + 1]}
		elseif k_words > 6 and i % k_words == 5 then
			tmp = {sbox[tmp[1] + 1], sbox[tmp[2] + 1], sbox[tmp[3] + 1], sbox[tmp[4] + 1]}
		end
		words[i] = {bxor(words[i - k_words][1], tmp[1]), bxor(words[i - k_words][2], tmp[2]),
			bxor(words[i - k_words][3], tmp[3]), bxor(words[i - k_words][4], tmp[4])}
	end

	return words
end

local function add_round_key(m1, k1, k2, k3, k4)
	return {
		bxor(k1[1], m1[1]), bxor(k1[2], m1[2]), bxor(k1[3], m1[3]), bxor(k1[4], m1[4]),
		bxor(k2[1], m1[5]), bxor(k2[2], m1[6]), bxor(k2[3], m1[7]), bxor(k2[4], m1[8]),
		bxor(k3[1], m1[9]), bxor(k3[2], m1[10]), bxor(k3[3], m1[11]), bxor(k3[4], m1[12]),
		bxor(k4[1], m1[13]), bxor(k4[2], m1[14]), bxor(k4[3], m1[15]), bxor(k4[4], m1[16]),
	}
end
local function sub_bytes(m1, inverse)
	for i=1,#m1 do
		m1[i] = (inverse and isbox or sbox)[m1[i] + 1]
	end
	return m1
end

local function aes_encrypt(input, key)
	input = input:len() % 16 == 0 and input:len() > 0 and input or input .. rep("\0", 16 - input:len() % 16)
	key = key:len() % 16 == 0 and key:len() > 0 and key or key .. rep("\0", 16 - key:len() % 16)

	local matrix = {}
	local rounds = key:len() / 4 + 6
	local round = 1

	local words = expand_key(key, (rounds + 1) * 4)

	matrix = {byte(input, 1, input:len())}

	local function shift_rows(m1)
		return {
			m1[1], m1[6], m1[11], m1[16], m1[5], m1[10], m1[15], m1[4],
			m1[9], m1[14], m1[3], m1[8], m1[13], m1[2], m1[7], m1[12]
		}
	end
	local function mix_columns(m1)
		local tmp = {}
		for i=1,4 do
			tmp[i * 4 - 3] = bxor(bxor(gf_mul(2, m1[i * 4 - 3]), gf_mul(3, m1[i * 4 - 2])), bxor(m1[i * 4 - 1], m1[i * 4]))
			tmp[i * 4 - 2] = bxor(bxor(m1[i * 4 - 3], gf_mul(2, m1[i * 4 - 2])), bxor(gf_mul(3, m1[i * 4 - 1]), m1[i * 4]))
			tmp[i * 4 - 1] = bxor(bxor(m1[i * 4 - 3], m1[i * 4 - 2]), bxor(gf_mul(2, m1[i * 4 - 1]), gf_mul(3, m1[i * 4])))
			tmp[i * 4] = bxor(bxor(gf_mul(3, m1[i * 4 - 3]), m1[i * 4 - 2]), bxor(m1[i * 4 - 1], gf_mul(2, m1[i * 4])))
		end
		return tmp
	end

	matrix = add_round_key(matrix, words[1], words[2], words[3], words[4])

	while round < rounds do
		matrix = add_round_key(mix_columns(shift_rows(sub_bytes(matrix))), words[round * 4 + 1], words[round * 4 + 2],
			words[round * 4 + 3], words[round * 4 + 4])
		round = round + 1
	end

	matrix = add_round_key(shift_rows(sub_bytes(matrix)), words[round * 4 + 1], words[round * 4 + 2],
		words[round * 4 + 3], words[round * 4 + 4])

	return char(unpack(matrix))
end

local function aes_decrypt(input, key)
	input = input:len() % 16 == 0 and input:len() > 0 and input or input .. rep("\0", 16 - input:len() % 16)
	key = key:len() % 16 == 0 and key:len() > 0 and key or key .. rep("\0", 16 - key:len() % 16)

	local round = key:len() / 4 + 6
	local words = expand_key(key, (round + 1) * 4)
	local matrix = add_round_key({byte(input, 1, input:len())},
		words[#words - 3], words[#words - 2], words[#words - 1], words[#words])

	local function ishift_rows(m1)
		return {
			m1[1], m1[14], m1[11], m1[8], m1[5], m1[2], m1[15], m1[12],
			m1[9], m1[6], m1[3], m1[16], m1[13], m1[10], m1[7], m1[4]
		}
	end
	local function imix_columns(m1)
		local tmp = {}
		for i=1,4 do
			tmp[i * 4 - 3] = bxor(bxor(gf_mul(14, matrix[i * 4 - 3]), gf_mul(11, matrix[i * 4 - 2])),
				bxor(gf_mul(13, matrix[i * 4 - 1]), gf_mul(9, matrix[i * 4])))
			tmp[i * 4 - 2] = bxor(bxor(gf_mul(9, matrix[i * 4 - 3]), gf_mul(14, matrix[i * 4 - 2])),
				bxor(gf_mul(11, matrix[i * 4 - 1]), gf_mul(13, matrix[i * 4])))
			tmp[i * 4 - 1] = bxor(bxor(gf_mul(13, matrix[i * 4 - 3]), gf_mul(9, matrix[i * 4 - 2])),
				bxor(gf_mul(14, matrix[i * 4 - 1]), gf_mul(11, matrix[i * 4])))
			tmp[i * 4] = bxor(bxor(gf_mul(11, matrix[i * 4 - 3]), gf_mul(13, matrix[i * 4 - 2])),
				bxor(gf_mul(9, matrix[i * 4 - 1]), gf_mul(14, matrix[i * 4])))
		end
		return tmp
	end

	while round > 0 do
		matrix = add_round_key(sub_bytes(ishift_rows(matrix), true),
			words[round * 4 - 3], words[round * 4 - 2], words[round * 4 - 1], words[round * 4])
		matrix = round ~= 1 and imix_columns(matrix) or matrix
		round = round - 1
	end

	return char(unpack(matrix))
end
