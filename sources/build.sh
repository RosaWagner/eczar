#!/usr/bin/env bash

if [ -z $1 ]
then
	echo "Use: build.sh -d -i -r -t -o -x -z"
	echo "-d   deletes old instances"
	echo "-i   interpolate new instances"
	echo "-r   generate TTF instances from UFO instances by way of RoboFont"
	echo "-t   build TTF fonts"
	echo "-o   build OTF fonts"
	echo "-x   make TTX files from the OTFs and TTFs"
	echo "-z   create zip for release, needs a family name as parameter,"
	echo "     this filters the fonts that are included in the release"
fi

while getopts dirtoxz: option
do
	case "${option}" in
		d) DELETE="D";;
		i) INTERPOLATE="I";;
		r) ROBO="R";;
		t) TTF="T";;
		o) OTF="O";;
		x) TTX="X";;
		z) ZIP=${OPTARG};;
	esac
done

# work from the production directory all the time
cd ../production

for FAMILY in */
do
	# remove trailing slash
	FAMILY=`echo "$FAMILY" | sed -e "s/\([^-\.]*\)\//\1/"`

	# delete old UFO instances
	if [ $DELETE ]
	then
		cd "$FAMILY"
		shopt -s nullglob
		for i in */
		do
			oldUFO=$i"font.ufo"
			oldTTF=$i"font.ttf"
			oldOTF=$i"font.otf"
			if [[ -d $oldUFO ]]
			then
				echo "Removing old $oldUFO"
				rm -R $oldUFO
			fi
			if [[ -f $oldTTF ]]
			then
				echo "Removing old $oldTTF"
				rm $oldTTF
			fi
			if [[ -f $oldOTF ]]
			then
				echo "Removing old $oldOTF"
				rm $oldOTF
			fi
		done
		cd ..
	fi

	# generate new UFO instances & feature files
	if [ $INTERPOLATE ]
	then
		cd "$FAMILY"
		for ds in *.designspace
		do
			makeInstancesUFO -d $ds
		done
		for i in */
		do
			cd "$i"
			addGroupsUFO.py -g ../uprights.groups.txt font.ufo
			cd ..
		done
		generateAllKernFiles.py
		generateAllMarkFiles.py
		cd ..
	fi

	# generate TTFs from UFOs (via RoboFont)
	if [ $ROBO ]
	then	
		cd "$FAMILY"
		for i in */
		do
			cd "$i"
			echo "Generating TTF in $FAMILY/$i"
			roboGenerateFont.py font.ufo -r -c -f ttf
			cd ..
		done
		cd ..
	fi

	# build TTF fonts
	if [ $TTF ]
	then
		mkdir -p ../fonts/ttf
		cd "$FAMILY"
		for i in */
		do
			cd "$i"
			STYLE=`echo "$i" | sed -e "s/\([^-\.]*\)\//\1/"`
			FONT=../../../fonts/ttf/$FAMILY-$STYLE.ttf
			echo "Building TTF fonts from $FAMILY/$i"
			makeotf -f font.ttf -o $FONT -ff features.fea -gf GlyphOrderAndAliasDB -r
			
			# subset if there is sunset.txt file in family folder
			if [[ -f "../subset.txt" ]]
			then
				pyftsubset $FONT --unicodes-file=../subset.txt --output-file=$FONT.S --layout-features='*' --glyph-names --notdef-glyph --notdef-outline --recommended-glyphs --name-IDs='*' --name-legacy --name-languages='*' --legacy-cmap --no-symbol-cmap --no-ignore-missing-unicodes
				rm $FONT
				mv $FONT.S $FONT
			fi
			# autohint
			ttfautohint $FONT $FONT.AH --hinting-range-max=96 --ignore-restrictions --stem-width-mode=qsq --increase-x-height=14
			rm $FONT
			mv $FONT.AH $FONT
			cd ..
		done
		cd ..
	fi

	# build OTF fonts
	if [ $OTF ]
	then
		mkdir -p ../fonts/otf
		cd "$FAMILY"
		for i in */
		do
			cd "$i"
			STYLE=`echo "$i" | sed -e "s/\([^-\.]*\)\//\1/"`
			FONT=../../../fonts/otf/$FAMILY-$STYLE.otf
			echo "Building OTF fonts from $FAMILY/$i"
			makeotf -f font.ufo -o $FONT -ff features.fea -gf GlyphOrderAndAliasDB -r
			
			# subset if there is sunset.txt file in family folder
			if [[ -f "../subset.txt" ]]
			then
				pyftsubset $FONT --unicodes-file=../subset.txt --output-file=$FONT.S --layout-features='*' --glyph-names --notdef-glyph --notdef-outline --recommended-glyphs --name-IDs='*' --name-legacy --name-languages='*' --legacy-cmap --no-symbol-cmap --no-ignore-missing-unicodes
				rm $FONT
				mv $FONT.S $FONT
			fi
			cd ..
		done
		cd ..
	fi
done

# get out of the production directory
cd ..

# make TTX files
if [ $TTX ]
then
	echo "Making TTX files from compiled OTF/TTF fonts."
	rm fonts/otf/*.ttx
	ttx -s fonts/otf/*.otf
	rm fonts/ttf/*.ttx
	ttx -s fonts/ttf/*.ttf
fi

# zip for release
if [ $ZIP ]
then
	echo "Creating zip file for release."
	FAMILY=$ZIP
	VERSION=`cat production/version.fea`
	zipname="$FAMILY-fonts-v$VERSION"
	mkdir -p $FAMILY/otf
	mkdir -p $FAMILY/ttf
	cp fonts/otf/$FAMILY*.otf $FAMILY/otf/
	cp fonts/ttf/$FAMILY*.ttf $FAMILY/ttf/
	cp documentation/FONTLOG.md $FAMILY/FONTLOG.txt
	cp README.md $FAMILY/README.txt
	cp LICENSE.txt $FAMILY
	zip $zipname.zip -r $FAMILY/*
	rm -R $FAMILY
fi
