create-bundle-volume:
	docker volume create --name jekyll-bundle

update-bundle:
	docker run \
		--volume="$(PWD):/srv/jekyll" \
		--mount type=volume,source=jekyll-bundle,target=/usr/local/bundle \
		-p 4000:4000 \
		-it jekyll/jekyll:4 \
	bundle update

drafts:
	docker run --rm \
		--volume="$(PWD):/srv/jekyll" \
		--volume="$(PWD)/vendor/bundle:/usr/local/bundle" \
		-p 4000:4000 \
		-it jekyll/jekyll:4 \
	jekyll serve --drafts
