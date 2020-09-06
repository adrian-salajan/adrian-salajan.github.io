continue:
	#git stash pop
	rm -rf _site/*
	git stash show -p | git apply && git stash drop
	rsync -a _site/* ..