#!/bin/bash
#########################################################################################################
function do_pandoc_recursive {

local markdown_src_file_extension=\*.markdown
local markdown_src_path="$1"
local html_output_path="$2"
mkdir "$html_output_path" 2>/dev/null


for input_file_name in $(find $markdown_src_path -name $markdown_src_file_extension 2>/dev/null | cut --delimiter='/' --fields=2- )
do
	mkdir "$html_output_path"/$(dirname $input_file_name) 2>/dev/null
	pandoc -rmarkdown -whtml "$markdown_src_path"/"$input_file_name" --output="$html_output_path"/"$input_file_name".html
done

}
#########################################################################################################
do_pandoc_recursive "1.markdown.src" "0.html.output"
#########################################################################################################
