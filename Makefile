.PHONY: slides
slides:
	pandoc slides.md \
		--pdf-engine xelatex \
		--write beamer \
		--output slides.pdf

.PHONY: watch
watch:
	watchexec --exts 'md' make slides
