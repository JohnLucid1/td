package main 


import "core:fmt"
import "core:os"
import "core:mem"
import "core:slice"
import "core:log"
import "core:strings"
import "core:path/filepath"


// TODO: get all files recursevly 
// TODO: find a better way to parse files
DEBUG :: false
main :: proc()  {
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
	
	f, err := os.open(dir, os.O_RDONLY); if err != 0 {
		log.errorf("[ERROR]:", err)
		return
	}
	
	files, errf := os.read_dir(f, -1); if errf != 0 {
		log.errorf("[ERROR]:", err)
		return
	}
		
	step_through(files)
	delete(files)
}

Todo :: struct {
	path: string,
	content: string,
	clm : uint, 
	line: uint,	
	prior: uint,
}



step_through :: proc(files: []os.File_Info) {
	todos := make([dynamic]Todo)
	
	for file in files {
		line_n :uint = 0
		if os.is_file(file.fullpath) && filepath.ext(file.fullpath) != ".exe"{
			content, ok := os.read_entire_file(file.fullpath); if !ok {
				log.panic("Couldn't load content of file")
			}
			str_content := string(content)
			defer delete(str_content)
			
			lines := strings.split_lines(str_content)
			defer delete(lines)
			
			for line in lines {
				line_n += 1
				if strings.contains(line, "TODO"){
					prior := find_os(line)
					append(&todos, Todo{file.name, line, 0, line_n, prior})
				}
			}
		}
	}

	slice.reverse_sort_by(todos[:], proc(i, j: Todo)->bool {return i.prior < j.prior})
	for i in todos {
		//           rs       rd       ys        yd      
		fmt.printf("\033[91m%s\033[0m:\033[93m%d\033[0m:\t%s\n", i.path, i.line, i.content)
	}
	delete(todos)
}



find_os :: proc(content: string) -> uint {
	important := content[strings.index(content, "TODO")+4:]
	acc :uint= 0
	for i := 0; i < len(important); i+=1 {
		if important[i] == 'O' || important[i] == 'o' do acc+=1
		else do break
	}
	return acc
}
