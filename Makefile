build:
	cd src && \
	nim c main.nim

release:
	cd src && \
	nim -d:release --mm:orc --threads:off c main

