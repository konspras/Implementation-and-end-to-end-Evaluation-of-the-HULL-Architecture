import numpy as np
import csv
import sys

import matplotlib
matplotlib.use('agg')
import matplotlib.pyplot as plt

# Rows: data source (ex 10 servers, 1 server, workload 1 etc)
# Cols: load levels
loads = range(10,110,10)
shape = (len(sys.argv)-1, len(loads))
send_times = []
receive_times = []
latencies = []
max_latency_per_query = [[None for col in range(0,shape[1])] 
                            for row in range(0,shape[0])]
means = np.ndarray(shape=shape)
means_99 = np.ndarray(shape=shape)

def main():
    for i, path in enumerate(sys.argv[1:]):
        load_files(path, i)
    #Create mean_latency - load graph
    fig, ax = plt.subplots(nrows=1, ncols=1, figsize=(20,10))
    for row in range(0,shape[0]):
        ax.plot(loads, means[row]*1000.0, label="mean", marker='o') 
        ax.plot(loads, means_99[row]*1000.0, label="99%", marker='o')     
    
    ax.set_title("Avereage Latency vs Server Load")
    ax.legend(loc='upper left')
    ax.set_ylabel('miliseconds')
    ax.set_xlabel('Server Load')
    ax.grid(linestyle="-")
    ax.set_xlim(left=loads[0], right=loads[len(loads)-1])
    fig.tight_layout()   
    fig.savefig("plots/lat_vs_load.png", format="png")

    # Create latency vs time graph
    if len(sys.argv) < 3:
        fig, ax = plt.subplots(nrows=1, ncols=1, figsize=(20,10))
        for arr, load in zip(max_latency_per_query[::2], loads[::2]):
            ax.plot(arr*1000.0, ",", marker='o', label=str(load)+"%", markersize = 2) 
        #ax.plot(loads, means_99*1000.0, label="99%", marker='o') 
        ax.set_title("Per Query Latency")
        ax.legend(loc='upper left')
        ax.set_ylabel('miliseconds')
        ax.set_xlabel('Query ID')
        ax.grid(linestyle="-")
        #ax.set_xlim(left=loads[0], right=loads[len(loads)-1])
        fig.tight_layout()   
        fig.savefig("plots/lat_vs_time.png", format="png")



def load_files(path, file_num):
    for i, load in enumerate(loads):
        tmp_send_times = np.genfromtxt(path+"send_latencies"+str(load)+".csv", delimiter=",")
        tmp_receive_times = np.genfromtxt(path+"rec_latencies"+str(load)+".csv", delimiter=",")
        tmp_send_times = tmp_send_times[:,0:tmp_send_times.shape[1]-1]
        tmp_receive_times = tmp_receive_times[:,0:tmp_receive_times.shape[1]-1]
        tmp_latencies = tmp_receive_times - tmp_send_times
        tmp_max_latency_per_query = np.amax(tmp_latencies, axis=1)
        tmp_sorted_per_query = np.sort(tmp_max_latency_per_query)
        # 99th percentile
        tmp_std = np.std(tmp_sorted_per_query)
        tmp_percentile_99 = tmp_sorted_per_query[round(0.99*tmp_sorted_per_query.shape[0]):]
        tmp_std_99 = np.mean(tmp_percentile_99)

        # Save to global vars
        means[file_num, i] = np.mean(tmp_sorted_per_query)
        means_99[file_num, i] = np.mean(tmp_percentile_99)
        #send_times.append(tmp_receive_times)
        #receive_times.append(tmp_receive_times)
        #latencies.append(tmp_latencies)
        max_latency_per_query[file_num][i] = tmp_max_latency_per_query


if __name__ == "__main__":
    main()

