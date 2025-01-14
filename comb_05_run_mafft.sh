
echo -e "\e[38;2;52;252;252m* Run MAFFT for gaps between synteny blocks\e[0m"

# ----------------------------------------------------------------------------
#            ERROR HANDLING BLOCK
# ----------------------------------------------------------------------------

# Exit immediately if any command returns a non-zero status
set -e

# Keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG

# Define a trap for the EXIT signal
trap 'catch $?' EXIT

# Function to handle the exit signal
catch() {
    # Check if the exit code is non-zero
    if [ $1 -ne 0 ]; then
        echo "\"${last_command}\" command failed with exit code $1."
    fi
}

# ----------------------------------------------------------------------------
#             FUNCTIONS
# ----------------------------------------------------------------------------

source utils_bash.sh

# ----------------------------------------------------------------------------
#             PARAMETERS
# ----------------------------------------------------------------------------

# Инициализация переменных

# Разбор аргументов командной строки
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --cores) cores="$2"; shift ;;
        --path.mafft.in) path_mafft_in="$2"; shift ;;
        --path.mafft.out) path_mafft_out="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done


# Установка значения по умолчанию для cores, если оно не было задано
if [ -z "$cores" ]; then
    cores=1
fi
# echo "Number of cores ${cores}"

check_missing_variable "path_mafft_in"
check_missing_variable "path_mafft_out"

path_mafft_in=$(add_symbol_if_missing "$path_mafft_in" "/")
path_mafft_out=$(add_symbol_if_missing "$path_mafft_out" "/")


# Проверяем, существует ли выходная директория, если нет - создаем
if [ ! -d "${path_mafft_out}" ]; then
    mkdir -p "${path_mafft_out}"
fi


# ----------------------------------------------------------------------------
#                MAIN
# ----------------------------------------------------------------------------

trap "echo 'Script interrupted'; exit" INT

declare -A running_jobs

# Iterating over all .fasta files in the input directory
for input_file in "${path_mafft_in}"/*.fasta; do
# find "${path_mafft_in}" -maxdepth 1 -name "*.fasta" | while read input_file; do
    # Check if .fasta files exist
    if [ ! -e "$input_file" ]; then
        echo "No .fasta files found in input directory for MAFFT."
        break
    fi

    # Extracting the file name without extension for use in the output file
    base_name=$(basename "${input_file}" .fasta)
    output_file="${path_mafft_out}/${base_name}_aligned.fasta"

    if [ -e "$output_file" ]; then
        continue
    fi

    # Run MAFFT in parallel
    timeout --foreground 100 mafft --op 5 --quiet --maxiterate 100 "${input_file}" > "${output_file}" &
    job_pid=$!

    running_jobs[$job_pid]=1

    # Check the number of running processes
    while (( ${#running_jobs[@]} >= $cores )); do
        for pid in "${!running_jobs[@]}"; do
            if ! kill -0 $pid 2>/dev/null; then
                unset running_jobs[$pid]
            fi
        done
        sleep 1
    done
done

# Wait for all processes to finish
for pid in "${!running_jobs[@]}"; do
    wait $pid
done

echo "  Done!"
