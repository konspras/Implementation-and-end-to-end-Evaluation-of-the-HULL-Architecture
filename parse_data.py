import numpy as np
import csv
import sys
import os

import matplotlib
matplotlib.use('agg')
import matplotlib.pyplot as plt




def main():
    out_file_name = sys.argv[1]
    number_of_paths = int(sys.argv[2])
    paths = sys.argv[3:3+number_of_paths]
    x_axis_title = sys.argv[3+number_of_paths] 
    x_axis = sys.argv[4+number_of_paths:]

    # Rows: number of different variables to be plotted
    # Cols: number of x_axis parameter values 
    shape = (len(paths), len(x_axis))
    # Initialize data sequences
    max_latency_per_query = [[None for col in range(0,shape[1])] 
                            for row in range(0,shape[0])]
    means = np.ndarray(shape=shape)
    means_99 = np.ndarray(shape=shape)
    for path_num, path in enumerate(paths):
        load_files(path_num, path, x_axis, max_latency_per_query, means, means_99)

    #Create mean_latency - x_axis graph
    fig, ax = plt.subplots(nrows=1, ncols=1, figsize=(20,10))
    for i in range(0,shape[0]):
        label = paths[i].split("/")[-1]
        ax.plot(x_axis, means[i]*1000.0, label="mean "+label, marker='o') 
        ax.plot(x_axis, means_99[i]*1000.0, ':', label="99th% "+label, marker='o')     
    
    ax.set_title("Average Latency vs " + x_axis_title)
    ax.legend(loc='upper left')
    ax.set_ylabel('miliseconds')
    ax.set_xlabel(x_axis_title)
    ax.grid(linestyle="-")
    ax.set_xlim(left=x_axis[0], right=x_axis[len(x_axis)-1])
    fig.tight_layout()   
    try:
        os.makedirs("plots/"+out_file_name)
    except FileExistsError:
        "Plots file already exists"
    fig.savefig("plots/"+out_file_name+"/Latency_vs_"+x_axis_title+".png", format="png")

    # Create latency vs time graph
    # if len(sys.argv) < 3:
    #     fig, ax = plt.subplots(nrows=1, ncols=1, figsize=(20,10))
    #     for arr, load in zip(max_latency_per_query[::2], x_axis[::2]):
    #         ax.plot(arr*1000.0, ",", marker='o', label=str(load)+"%", markersize = 2) 
    #     #ax.plot(loads, means_99*1000.0, label="99%", marker='o') 
    #     ax.set_title("Per Query Latency")
    #     ax.legend(loc='upper left')
    #     ax.set_ylabel('miliseconds')
    #     ax.set_xlabel('Query ID')
    #     ax.grid(linestyle="-")
    #     #ax.set_xlim(left=loads[0], right=loads[len(loads)-1])
    #     fig.tight_layout()   
    #     fig.savefig("plots/lat_vs_time.png", format="png")



def load_files(file_num, path, x_axis, max_latency_per_query, means, means_99):
    for i, x_val in enumerate(x_axis):
        tmp_send_times = np.genfromtxt(path+"/send_times"+str(x_val)+".csv", delimiter=",")
        tmp_receive_times = np.genfromtxt(path+"/rec_times"+str(x_val)+".csv", delimiter=",")
        tmp_send_times = tmp_send_times[:,0:tmp_send_times.shape[1]-1]
        tmp_receive_times = tmp_receive_times[:,0:tmp_receive_times.shape[1]-1]
        #print(tmp_send_times)
        #print(tmp_receive_times)
        tmp_latencies = tmp_receive_times - tmp_send_times
        tmp_max_latency_per_query = np.amax(tmp_latencies, axis=1)
        tmp_sorted_per_query = np.sort(tmp_max_latency_per_query)
        tmp_std = np.std(tmp_sorted_per_query)
        tmp_percentile_99 = tmp_sorted_per_query[round(0.99*tmp_sorted_per_query.shape[0]):]
        tmp_std_99 = np.mean(tmp_percentile_99)

        # Save and return
        means[file_num, i] = np.mean(tmp_sorted_per_query)
        means_99[file_num, i] = np.mean(tmp_percentile_99)
        max_latency_per_query[file_num][i] = tmp_max_latency_per_query


if __name__ == "__main__":
    main()

