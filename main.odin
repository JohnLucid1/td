package main
import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:strings"
import "core:unicode"


DEBUG :: false
get_files :: proc(
	info: os.File_Info,
	in_err: os.Errno,
	user_data: rawptr,
) -> (
	err: os.Errno,
	skip_dir: bool,
) {
	if info.is_dir {
		return 0, false
	}
	if strings.contains(info.fullpath, "git") || strings.contains(info.fullpath, ".exe") {
		return 0, false
	} else {
		append(&thingy, info)
		return 0, false
	}
	return 0, false
}

// TODO: find a better way to parse files
thingy := [dynamic]os.File_Info{}
main :: proc() {
	when DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			if len(track.bad_free_array) > 0 {
				fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
				for entry in track.bad_free_array {
					fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}


	dir := "./"

	if len(os.args) > 1 {
		dir = os.args[1]
	}

	f, err := os.open(dir, os.O_RDONLY);if err != 0 {
		log.errorf("[ERROR]:", err)
		return
	}

	erri := filepath.walk(dir, get_files, nil)
	if erri != 0 {
		log.errorf("[ERROR]:", erri)
		return
	}


	step_through(thingy[:])
	delete(thingy)
}

Todo :: struct {
	path:    string,
	content: string,
	clm:     uint,
	line:    uint,
	prior:   uint,
}


step_through :: proc(files: []os.File_Info) {
	todos := make([dynamic]Todo)

	for file in files {
		line_n: uint = 0
		if os.is_file(file.fullpath)  {
			content, ok := os.read_entire_file(file.fullpath);if !ok {
				log.panic("Couldn't load content of file")
			}
			str_content := string(content)
				
			lines := strings.split_lines(str_content)
			for line in lines {
				line_n += 1
				if strings.contains(line, "TODO") && line[strings.index(line, "DO")+2] != '\''{
					prior := find_os(line)
					append(&todos, Todo{file.name, line, 0, line_n, prior})
				}
			}
		}
	}

	slice.reverse_sort_by(todos[:], proc(i, j: Todo) -> bool {return i.prior < j.prior})
	for i in todos {
		//           rs       rd       ys        yd      
		fmt.printf("\033[91m%s\033[0m:\033[93m%d\033[0m:\033[94m%s\n", i.path, i.line, i.content)
	}
	
	delete(todos)
}


find_os :: proc(content: string) -> uint {
	important := content[strings.index(content, "TODO") + 4:]
	acc: uint = 0
	for i := 0; i < len(important); i += 1 {
		if important[i] == 'O' || important[i] == 'o' do acc += 1
		else do break
	}

	when DEBUG {
		fmt.println("[DEBUG important]:", important)
	}
	return acc
}
