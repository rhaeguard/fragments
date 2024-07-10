torrent_file = "ubuntu-24.04-desktop-amd64.iso.torrent"
torrent_content = File.read(torrent_file)

DICT_START = 100 # d
LIST_START = 108 # l
INT_START = 105 # i
END_CHAR = 101 # e
DIVIDER = 58 # :

alias BencodeObject = Int64 | String | Hash(String, BencodeObject) | Array(BencodeObject)

def parse_int(bencode : Slice(UInt8), pos : Pointer(Int32)) : Int64
    pos.value += 1 # skip i
    start = pos.value

    while bencode[pos.value] != END_CHAR
        pos.value += 1
    end

    number = Int64.new(String.new(bencode[start, (pos.value - start)]))
    
    pos.value += 1

    return number
end

def parse_list(bencode : Slice(UInt8), pos : Pointer(Int32)) : Array(BencodeObject)
    pos.value += 1 # skip l
    start = pos.value

    list = [] of BencodeObject

    while bencode[pos.value] != END_CHAR
        list << parse_bencode_object(bencode, pos)
    end

    pos.value += 1

    return list
end

def parse_dict(bencode : Slice(UInt8), pos : Pointer(Int32)) : Hash(String, BencodeObject)
    pos.value += 1 # skip d
    start = pos.value

    dict = {} of String => BencodeObject
    
    while bencode[pos.value] != END_CHAR
        key = parse_string(bencode, pos)
        value = parse_bencode_object(bencode, pos)
        dict[key] = value
    end

    pos.value += 1

    return dict
end

def parse_string(bencode : Slice(UInt8), pos : Pointer(Int32)) : String
    x = pos.value
    while bencode[x] != DIVIDER
        x += 1
    end
    length_as_string = bencode[pos.value, (x - pos.value)]
    length = String.new(length_as_string).to_i
    text = bencode[x + 1, length]
    pos.value = x + length + 1
    return String.new(text)
end

def parse_bencode_object(bencode : Slice(UInt8), pos : Pointer(Int32)) : BencodeObject
    string_length = bencode.size

    if pos.value < string_length-1
        cur_char = bencode[pos.value]
        if cur_char == INT_START
            return parse_int(bencode, pos)
        elsif cur_char == LIST_START
            return parse_list(bencode, pos)
        elsif cur_char == DICT_START
            return parse_dict(bencode, pos)
        else
            return parse_string(bencode, pos)
        end
    end 

    return ""
end

def parse(bencode : String) : BencodeObject
    content_in_bytes = bencode.to_slice
    start = 0
    ptr = pointerof(start)
    return parse_bencode_object(content_in_bytes, ptr)
end


r = parse(torrent_content)

puts r