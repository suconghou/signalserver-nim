build:
	cd src && \
	nim c main.nim

release:
	cd src && \
	nim c -d:release main.nim

ssl:
	cd src && \
	nim c -d:ssl -d:release main.nim

