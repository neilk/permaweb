Breakaway

requires gmake and other coreutils

to make the build dir, 

gmake clean && gmake

to upload, use rsync, as in 

cd build
rsync -av --delete . brevity@brevity.org:neilk.net

