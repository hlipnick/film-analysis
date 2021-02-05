#!/bin/sh

#########

# Originally Created by Harry Lipnick 2/5/21

#########

# Make Sure Required Tools are Installed
checkForRequiredTool() {
    commandName="$1"
    if ! command -v $commandName &> /dev/null
    then
        echo "This script requires $commandName but it could not be found."
        echo "Please install it on your system before trying again."
        echo "You may be able to use a package manager like homebrew (https://brew.sh) to install $commandName"
        echo "Exiting now."
        exit
    fi
}

# Check for gnuplot, ImageMagick's identify and bc
checkForRequiredTool gnuplot
checkForRequiredTool identify
checkForRequiredTool bc


while [ "$1" != "" ]; do
        case $1 in
                --inputDirectory | -i ) shift
                        inputDirectory=$1
                        ;;
                --outputDirectory | -o ) shift
                        outputDirectory=$1
                        ;;
                --cropWidth | -w ) shift
                        cropWidth=$1
                        ;;
                --cropHeight | -h ) shift
                        cropHeight=$1
                        ;;
                --cropX | -x ) shift
                        cropX=$1
                        ;;
                --cropY | -y ) shift
                        cropY=$1
                        ;;
        esac
        shift
done

# Interactively get paramters that were not provided on command prompt
echo "Enter the Parameters:"
if [ -z "$inputDirectory" ]; then read -p "Enter the Input Directory (i.e. Folder full of DPX stills): " inputDirectory; fi
if [ -z "$outputDirectory" ]; then read -p "Enter the Output Directory (Where output CSV and graph should be saved): " outputDirectory; fi
if [ -z "$cropWidth" ]; then read -p "Enter Gray Card Cropping Square Width (pixels): " cropWidth; fi
if [ -z "$cropHeight" ]; then read -p "Enter Gray Card Cropping Square Height (pixels): " cropHeight; fi
if [ -z "$cropX" ]; then read -p "Enter Gray Card Cropping Square X (pixels offset from top left corner of image): " cropX; fi
if [ -z "$cropY" ]; then read -p "Enter Gray Card Cropping Square Y (pixels offset from top left corner of image): " cropY; fi

# Exit Script if Required Parameters Not Provided
# if [ -z "$inputDirectory" ]; then echo "No input directory was provided.  Script cannot continue without it.  Exiting now."; exit; fi
# if [ -z "$outputDirectory" ]; then echo "No output directory was provided.  Script cannot continue without it.  Exiting now."; exit; fi
# if [ -z "$cropWidth" ]; then echo "No crop width was provided.  Script cannot continue without it.  Exiting now."; exit; fi
# if [ -z "$cropHeight" ]; then echo "No crop height was provided.  Script cannot continue without it.  Exiting now."; exit; fi
# if [ -z "$cropX" ]; then echo "No crop X was provided.  Script cannot continue without it.  Exiting now."; exit; fi
# if [ -z "$cropY" ]; then echo "No crop Y was provided.  Script cannot continue without it.  Exiting now."; exit; fi

#######

# Make Input and Output Directories if they don't exist
if [ ! -d "$inputDirectory" ]; then
    echo "The provided input directory does not exist.  Cannot continue with non-existing input directory.  Exiting now."
    exit
fi

if [ ! -d "$outputDirectory" ]; then
    read -p "The provided output directory does not exist.  Should I create it? [Y/N] " -r;
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        mkdir -p "$outputDirectory"
    else
        echo "Cannot continue with non-existing output directory.  Existing now."
        exit
    fi
fi

# Generate Cropping Rect String for ImageMagick
cropRect="$cropWidth"x"$cropHeight"+"$cropX"+"$cropY"

# Get NUmber of Images in Input Directory
inputCount=$(ls "$inputDirectory" | wc -l | xargs)

# Determine Top of Graph X-Axis Range Based on Image Count
graphMaxX=$(echo "$inputCount - 1" | bc)

# Move to Input Directory
cd "$inputDirectory";

# Define and Create Empty Output Files
outputFile="$outputDirectory/values.csv";
graphOutput="$outputDirectory/values.png";

# Write Columns Headings to Output File
echo "R,G,B" > $outputFile;

# Loop through input files to derive R, G, B values (multiplied by 100) from gray card cropping area
n=0;
for inputFile in *;
    do
    n=$((n+1))
    echo "Processing file $n of $inputCount ($inputFile)..."
    r=$(identify -crop "$cropRect" -channel R -format "%[fx:mean]\n" "$inputFile");
    r=$(echo "$r*100" | bc);
    g=$(identify -crop "$cropRect" -channel G -format "%[fx:mean]\n" "$inputFile");
    g=$(echo "$g*100" | bc);
    b=$(identify -crop "$cropRect" -channel B -format "%[fx:mean]\n" "$inputFile");
    b=$(echo "$b*100" | bc);
    outputLine="$r,$g,$b"
    echo "$outputLine" >> "$outputFile"
done;

# Define Graph Output Parameteres for GNUPlot and write to temporary file gnu.plot
cd "$outputDir"
echo "" > gnu.plot
echo "set title 'DLogE'" >> gnu.plot
echo "set ylabel 'Value'" >> gnu.plot
echo "set xlabel 'X'" >> gnu.plot
echo "set xrange [1:$inputCount]" >> gnu.plot
echo "set yrange [0:100]" >> gnu.plot
echo "set grid" >> gnu.plot
echo "set term png size 1584, 1224" >> gnu.plot
echo "set output '$graphOutput'" >> gnu.plot
echo "set datafile separator comma" >> gnu.plot
echo "set style line 1 lc rgb '#FF0000' lt 1 lw 1" >> gnu.plot
echo "set style line 2 lc rgb '#00FF00' lt 1 lw 1" >> gnu.plot
echo "set style line 3 lc rgb '#0000FF' lt 1 lw 1" >> gnu.plot
echo "plot for [col=1:3] '$outputFile' using 0:col with lines ls col notitle" >> gnu.plot

# Create Graph with gnuplot
gnuplot gnu.plot

# Delete Configuration File
rm gnu.plot

# Cleanup
echo "Done!"
echo "Generated CSV data file and PNG graph."
echo "If successful, they will be saved in $outputDirectory"