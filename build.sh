cd 4.0;
mkdocs build;
cd ..;

rm -rf build
mkdir -p build;

mv 4.0/site build/4.0;

echo "<meta http-equiv=\"refresh\" content=\"0; url=/4.0/\">" > build/index.html;

