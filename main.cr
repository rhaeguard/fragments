require "digest"
require "digest/sha1"
require "uri"

torrent_file = "ubuntu-24.04-desktop-amd64.iso.torrent"
torrent_file = "big-buck-bunny.torrent"
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

def encode(obj : BencodeObject) : String

    case obj
    when String
        # do something
        txt = obj.as(String)
        bytes_len = txt.to_slice.size
        return "#{bytes_len}:#{txt}"
    when Int64
        num = obj.as(Int64)
        return "i#{num}e"
    when Array
        # do something
        arr = obj.as(Array(BencodeObject))
        result = "l"
        i = 0
        while i < arr.size
            result += encode(arr[i])
            i += 1
        end
        return result+"e"
    when Hash
        # do something
        dict = obj.as(Hash(String, BencodeObject))
        result = "d"
        dict.each do |entry|
            k, v = entry
            result += (encode(k) + encode(v))
        end
        result += "e"
        return result
    else
        raise "Unexpected type: #{typeof(obj)}"
    end 

end

def create_info_hash(bencode : Hash(String, BencodeObject)) : String
    bencoded_info = encode(bencode["info"])
    info_io = IO::Memory.new(bencoded_info)
    io = IO::Digest.new(info_io, Digest::SHA1.new)
    buffer = Bytes.new(20) # SHA1 size is 160 bits or 20 bytes
    io.read(buffer)
    return URI.encode_path(String.new(io.final))
end

def generate_peer_id(bencode : Hash(String, BencodeObject)) : String
    return "<PEER_ID>"
end

def connect_tracker(bencode : Hash(String, BencodeObject))
    info_hash = create_info_hash(bencode)
    peer_id = generate_peer_id(bencode)
    uploaded = 0
    downloaded = 0
    left = 0 # must be total size
    compact = 1 # compact 6-byte format response expected (4 bytes - host, 2 bytes - port)
    puts info_hash
end

parsed_bencode : Hash(String, BencodeObject) = parse(torrent_content).as(Hash(String, BencodeObject))
puts parsed_bencode
connect_tracker(parsed_bencode)