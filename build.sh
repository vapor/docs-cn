cd 4.0;
mkdocs build;
cd ..;

rm -rf site
mkdir -p site;

mv 4.0/site site/4.0;

echo "<meta http-equiv=\"refresh\" content=\"0; url=/4.0/\">" > site/index.html;

