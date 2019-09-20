#!/usr/bin/env lua53
if #arg < 1 then
    print("usage: " .. arg[0] .. " <file.bmp>")
    os.exit(1)
end

function BitAND(a,b)--Bitwise and
    local p,c=1,0
    while a>0 and b>0 do
        local ra,rb=a%2,b%2
        if ra+rb>1 then c=c+p end
        a,b,p=(a-ra)/2,(b-rb)/2,p*2
    end
    return c
end

-- Offset (hex) Offset (dec)    Size (bytes)    Windows BITMAPINFOHEADER[1]
-- 0A   10  4   location of the pixel data
-- 0E   14  4   the size of this header (40 bytes)
-- 12   18  4   the bitmap width in pixels (signed integer)
-- 16   22  4   the bitmap height in pixels (signed integer)
-- 1A   26  2   the number of color planes (must be 1)
-- 1C   28  2   the number of bits per pixel, which is the color depth of the image. Typical values are 1, 4, 8, 16, 24 and 32.
-- 1E   30  4   the compression method being used. See the next table for a list of possible values
-- 22   34  4   the image size. This is the size of the raw bitmap data; a dummy 0 can be given for BI_RGB bitmaps.
-- 26   38  4   the horizontal resolution of the image. (pixel per metre, signed integer)
-- 2A   42  4   the vertical resolution of the image. (pixel per metre, signed integer)
-- 2E   46  4   the number of colors in the color palette, or 0 to default to 2n
-- 32   50  4   the number of important colors used, or 0 when every color is important; generally ignored

-- See https://en.wikipedia.org/wiki/BMP_file_format#References for more info

-- Color table starts at 0x36 - 4 bpp = 16 colors * 4 bytes each

function read_bitmap(file)
    local f = assert(io.open(file, "rb"))
    local pixeldata = {}

    -- 0x0A contains the offset to the pixel data
    f:seek("set", 0x0A)
    offset = string.unpack("<I4", f:read(4))

    f:seek("set", 0x12)
    width = string.unpack("I4", f:read(4))

    f:seek("set", 0x16)
    height = string.unpack("I4", f:read(4))

    f:seek("set", 0x1c)
    bpp = string.unpack("I2", f:read(2))

    f:seek("set", 0x1e)
    compression = string.unpack("I4", f:read(4))

    if compression ~= 0x0 then
        print("compressed images are not supported.")
        os.exit(1)
    end

    print("offset: " .. string.format("0x%02X", offset))
    print("height: " .. height)
    print("width: " .. width)
    print("bpp: " .. bpp)

    rowsize = math.floor(bpp/8 * width)
    --padding = 0

    while rowsize % 4 ~= 0 do
       rowsize = rowsize +1
       --padding = padding +1
    end

    print("padded row size: " .. rowsize .. " bytes")

    if bpp > 24 then
        print(bpp .. " bpp images are not supported.  Please convert to a lower color depth.")
        os.exit(1)
    end

    print("pixel data bytes: " .. rowsize*height)

    -- Seek to pixel data location
    f:seek("set", offset)

    -- read pixel data into a nested table
    for i=1,height do

        r = {}

        if bpp == 4 then
            for j = 1, rowsize, 1 do
                p = string.byte(f:read(1));
                HiNIBBLE = math.floor(p / 0x10); -- High bits contain the color data.  Divide by 16 to produce an index number.
                LoNIBBLE = BitAND(p, 0x0F); -- Low bits contain the pixel value.  ASC AND &HF ASCII value AND 15
                table.insert(r, HiNIBBLE)
                table.insert(r, LoNIBBLE)
            end
        else
            for j = 1, rowsize, 1 do
                -- print(string.format("%02X", f:seek()))
                -- bpp/8 gives bytes per pixel
                n = math.floor(bpp/8)
                fmt = "I" .. n
                pxl = string.unpack(fmt, f:read(n))
                --print("pxl: ", string.format("%02X", pxl))
                table.insert(r, pxl)
            end
        end

        -- if padding > 0 then
            -- f:seek("cur", padding)
        -- end

        -- Read in padding if needed
        -- while #r % 4 ~= 0 do
        --     f:read(1)
        --     --table.insert(r, "\x00")
        -- end

        --print("#r: ", #r)

        table.insert(pixeldata, r)
        -- Seek to next row
        -- offset = offset + rowsize
    end

    f:close()
    return pixeldata
end

-- ANSI color codes
-- -- foreground
-- black = 30,
-- red = 31,
-- green = 32,
-- yellow = 33,
-- blue = 34,
-- magenta = 35,
-- cyan = 36,
-- white = 37,

-- -- background
-- onblack = 40,
-- onred = 41,
-- ongreen = 42,
-- onyellow = 43,
-- onblue = 44,
-- onmagenta = 45,
-- oncyan = 46,
-- onwhite = 47,

colors = {
    [0] = 30,
    [1] = 31,
    [2] = 32,
    [3] = 33,
    [4] = 30,
    [5] = 35,
    [6] = 36,
    [7] = 37,
    [8] = 30,
    [9] = 32,
    [0x0A] = 31,
    [0x0B] = 37,
    [0x0C] = 32,
    [0x0D] = 32,
    [0x0E] = 32,
    [0x0F] = 32,
    [0x10] = 35,
}

img = read_bitmap(arg[1])

--io.write("Uint16 pixels[" .. height .. "*" .. width .. "] = {\n")

nl = 10000

-- Read pixel data from the table and print out the hex values
-- Image data is read from the "bottom" up
for i = #img, 1, -1 do
    --io.write("\t");
    --io.write(nl .. " DATA ")
    rowdata = img[i]
    for n, v in ipairs(rowdata) do
        -- Lua 5.1 doesn't support bit shifts.  Dividing by 2^shift equals the same result.
        -- This produces an index number of 1 - 16 for color codes
        if bpp == 4 then
            q = v
        else
            q = math.floor(v / (2^(bpp-4)))
        end
        c_code = colors[q]
        --io.write("0x" .. v .. ", ")
        io.write('\27[' .. c_code .. 'm' .. string.format("%02X", v) .. '\27[0m')
    end
    io.write("\n");
    nl = nl + 1
end

--io.write("};\n");
