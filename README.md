# Semester Project

The general flow in order to obtain latency (for now) plots is:

### 1) Create a configuration file in configurations/
Set the parameters. One simulation will run for each combination
Example:
file_name='x_load'
loads='10 20 30 40 40 60 70 80 90 100'
nums_flows='1 5 10'
workload_types='1'

### 2) Run the appropriate script
depending on what the prefered x-axis of the plot (ex. server load levels ->coordinator_loads.sh). The first argument needs to be the configuration file
and the second should be 1 if the script should run the simulations (!=1 if the appropriate data is available). The script will run one simulation per parameter 
combination and store send and receive times in a results/name_of_config_file.
There, it will create one folder for each parameter combination other than the
x-axis parameter. It will then call the data_parser.py script to create the plots.
They will be placed in plots/name_of_config_file.
