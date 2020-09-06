build:
	git checkout source
	docker run --rm \
	--volume="$(shell PWD):/srv/jekyll" \
	--volume="$(shell PWD)/vendor/bundle:/usr/local/bundle" \
	-p 4000:4000 \
	-it jekyll/jekyll:4 \
	jekyll build
	#mv -f _site/* ..
	git add _site -f
	git stash push
	git checkout master

