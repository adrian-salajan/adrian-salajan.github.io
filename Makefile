build:
	git checkout source
	docker run --rm \
	--volume="$(shell PWD):/srv/jekyll" \
	--volume="$(shell PWD)/vendor/bundle:/usr/local/bundle" \
	-p 4000:4000 \
	-it jekyll/jekyll:4 \
	jekyll serve
	mv _site/* ..
	git stash push
	git checkout master
	git stash pop