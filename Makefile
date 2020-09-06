continue:
	#git stash pop
	git stash show -p | git apply && git stash drop
	rsync -a _site/* ..
 	#rm -rf _site/*