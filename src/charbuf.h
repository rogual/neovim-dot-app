#pragma once

#include <map>

class CharBuf
{
    public:
        struct cell_t
        {
            /* Max size of a single character is 29 bytes:
               Highest possible maxcombine = 6
               + 1 for the character itself = 7
               * maximum 4 bytes per UTF8 character = 28
               + 1 for null terminator = 29 */
            char string[29];
            uint32_t foreground;
            uint32_t background;
        };

        typedef std::pair<int, int> coord_t;

        void set(coord_t coord, cell_t cell)
        {
            map[coord] = cell;
        }

        const cell_t &get(coord_t coord)
        {
            map_t::const_iterator iter = map.find(coord);
            if (iter == map.end())
                return oob_cell;
            return iter->second;
        }

        CharBuf()
        {
            oob_cell.string[0] = ' ';
            oob_cell.string[1] = 0;
        }

    private:
        typedef std::map<coord_t, cell_t> map_t;
        map_t map;
        cell_t oob_cell;
};
