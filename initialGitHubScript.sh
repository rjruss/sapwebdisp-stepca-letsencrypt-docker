#!/bin/bash


while read i ;do

INF=$(echo $i|sed "s/.TEMPLATE//")
echo "${INF}"
cp -p  $i .${INF}

done < <(ls -a *.info.TEMPLATE)

#rm TEMPLATE*.info

mv env.TEMPLATE .env
cp .env TEMPLATE.env
