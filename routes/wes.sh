#!/bin/bash


##
## whole genome/exome/targeted variant discovery using BWA-MEM and GATK
##


# script filename
script_name=$(basename "${BASH_SOURCE[0]}")
route_name=${script_name/%.sh/}
echo -e "\n ========== ROUTE: $route_name ========== \n" >&2

# check for correct number of arguments
if [ ! $# == 2 ] ; then
	echo -e "\n $script_name ERROR: WRONG NUMBER OF ARGUMENTS SUPPLIED \n" >&2
	echo -e "\n USAGE: $script_name project_dir sample_name \n" >&2
	exit 1
fi

# standard route arguments
proj_dir=$(readlink -f "$1")
sample=$2

# additional settings
threads=$NSLOTS
code_dir=$(dirname "$(dirname "${BASH_SOURCE[0]}")")
qsub_dir="${proj_dir}/logs-qsub"

# display settings
echo " * proj_dir: $proj_dir "
echo " * sample: $sample "
echo " * code_dir: $code_dir "
echo " * qsub_dir: $qsub_dir "
echo " * threads: $threads "


#########################


# delete empty qsub .po files
rm -f ${qsub_dir}/sns.*.po*


#########################


# segments

# rename and/or merge raw input FASTQs
segment_fastq_clean="fastq-fastq-clean"
fastq_R1=$(grep -s -m 1 "^${sample}," "${proj_dir}/samples.${segment_fastq_clean}.csv" | cut -d ',' -f 2)
fastq_R2=$(grep -s -m 1 "^${sample}," "${proj_dir}/samples.${segment_fastq_clean}.csv" | cut -d ',' -f 3)
if [ -z "$fastq_R1" ] ; then
	bash_cmd="bash ${code_dir}/segments/${segment_fastq_clean}.sh $proj_dir $sample"
	($bash_cmd)
	fastq_R1=$(grep -m 1 "^${sample}," "${proj_dir}/samples.${segment_fastq_clean}.csv" | cut -d ',' -f 2)
	fastq_R2=$(grep -m 1 "^${sample}," "${proj_dir}/samples.${segment_fastq_clean}.csv" | cut -d ',' -f 3)
fi

# trim FASTQs with Trimmomatic
segment_fastq_trim="fastq-fastq-trim-trimmomatic"
fastq_R1_trimmed=$(grep -s -m 1 "^${sample}," "${proj_dir}/samples.${segment_fastq_trim}.csv" | cut -d ',' -f 2)
fastq_R2_trimmed=$(grep -s -m 1 "^${sample}," "${proj_dir}/samples.${segment_fastq_trim}.csv" | cut -d ',' -f 3)
if [ -z "$fastq_R1_trimmed" ] ; then
	bash_cmd="bash ${code_dir}/segments/${segment_fastq_trim}.sh $proj_dir $sample $threads $fastq_R1 $fastq_R2"
	($bash_cmd)
	fastq_R1_trimmed=$(grep -m 1 "^${sample}," "${proj_dir}/samples.${segment_fastq_trim}.csv" | cut -d ',' -f 2)
	fastq_R2_trimmed=$(grep -m 1 "^${sample}," "${proj_dir}/samples.${segment_fastq_trim}.csv" | cut -d ',' -f 3)
fi

# run BWA-MEM alignment
segment_align="fastq-bam-bwa-mem"
bam=$(grep -s -m 1 "^${sample}," "${proj_dir}/samples.${segment_align}.csv" | cut -d ',' -f 2)
if [ -z "$bam_bwa" ] ; then
	bash_cmd="bash ${code_dir}/segments/${segment_align}.sh $proj_dir $sample $threads $fastq_R1_trimmed $fastq_R2_trimmed"
	($bash_cmd)
	bam=$(grep -m 1 "^${sample}," "${proj_dir}/samples.${segment_align}.csv" | cut -d ',' -f 2)
fi

# remove duplicates
segment_dedup="bam-bam-dd-sambamba"
bam_dd=$(grep -s -m 1 "^${sample}," "${proj_dir}/samples.${segment_dedup}.csv" | cut -d ',' -f 2)
if [ -z "$bam_dd" ] ; then
	bash_cmd="bash ${code_dir}/segments/${segment_dedup}.sh $proj_dir $sample $threads $bam"
	($bash_cmd)
	bam_dd=$(grep -m 1 "^${sample}," "${proj_dir}/samples.${segment_dedup}.csv" | cut -d ',' -f 2)
fi





#########################


# combine summary from each step

sleep 30

summary_csv="${proj_dir}/summary-combined.wes.csv"

bash_cmd="
bash ${code_dir}/scripts/join-many.sh , X \
${proj_dir}/summary.${segment_fastq_clean}.csv \
${proj_dir}/summary.${segment_fastq_trim}.csv \
${proj_dir}/summary.${segment_align}.csv \
${proj_dir}/summary.${segment_dedup}.csv \
> $summary_csv
"
(eval $bash_cmd)


#########################


# delete empty qsub .po files
rm -f ${qsub_dir}/sns.*.po*


#########################


date



# end