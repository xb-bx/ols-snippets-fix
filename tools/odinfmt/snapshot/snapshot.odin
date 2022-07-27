package odinfmt_testing 

import "core:testing"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:fmt"

import "shared:odin/format"

format_file :: proc(filepath: string, allocator := context.allocator) -> (string, bool) {
	style := format.default_style
	style.max_characters = 80
	style.newline_style = .LF //We want to make sure it works on linux and windows.

	if data, ok := os.read_entire_file(filepath, allocator); ok {	
		return format.format(filepath, string(data), style, {.Optional_Semicolons}, allocator);
	} else {
		return "", false;
	}
}

snapshot_directory :: proc(directory: string) -> bool {
	matches, err := filepath.glob(fmt.tprintf("%v/*", directory))

	if err != .None {
		fmt.eprintf("Error in globbing directory: %v", directory)
	}

	for match in matches {	
		if strings.contains(match, ".odin") {
			snapshot_file(match) or_return
		}
	}

	for match in matches {
		if !strings.contains(match, ".snapshots") {
			if os.is_dir(match) {
				snapshot_directory(match)
			}
		}
	}

	return true
}

snapshot_file :: proc(path: string) -> bool {
	fmt.printf("Testing snapshot %v", path)


	snapshot_path := filepath.join(elems = {filepath.dir(path, context.temp_allocator), "/.snapshots", filepath.base(path)}, allocator = context.temp_allocator);

	formatted, ok := format_file(path, context.temp_allocator)

	if !ok {
		fmt.eprintf("Format failed on file %v", path) 
		return false
	}

	if os.exists(snapshot_path) {
		if snapshot_data, ok := os.read_entire_file(snapshot_path, context.temp_allocator); ok {
			if cast(string)snapshot_data != formatted {
				fmt.eprintf("\nFormatted file was different from snapshot file: %v", snapshot_path)
				os.write_entire_file(fmt.tprintf("%v_failed", snapshot_path), transmute([]u8)formatted)
				return false
			} 
			os.remove(fmt.tprintf("%v_failed", snapshot_path))
		} else {
			fmt.eprintf("Failed to read snapshot file %v", snapshot_path)
			return false
		}
	} else {
		os.make_directory(filepath.dir(snapshot_path, context.temp_allocator))
		ok = os.write_entire_file(snapshot_path, transmute([]byte)formatted)
		if !ok {
			fmt.eprintf("Failed to write snapshot file %v", snapshot_path)
			return false
		}
	}

	fmt.print(" - SUCCESS \n")

	return true
}