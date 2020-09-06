continue:
	git stash pop
	rsync -a _site/* ..
 	#rm -rf _site/*