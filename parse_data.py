import numpy as np
import csv
import sys
import os

import matplotlib
matplotlib.use('agg')
import matplotlib.pyplot as plt




def main():
    out_folder_name = sys.argv[1]
    number_of_paths = int(sys.argv[2])
    paths = sys.argv[3:3+number_of_paths]
    x_axis_title = sys.argv[3+number_of_paths] 
    x_axis = sys.argv[4+number_of_paths:]
    # print(out_folder_name)
    # print(number_of_paths)
    # print(paths)
    # print(x_axis_title)
    # print(x_axis)
    final_paths = []
    final_file_ids = []
    for path in paths:
        wk_indx = path.find("wrkld")
        workload = path[wk_indx+len("wrkld"):].split("|")[0]
        for char in workload:
            final_paths.append(path)
            final_file_ids.append(char)

    #print("------")
    #print(final_paths)
    #print(final_file_ids)
    
    # Rows: number of different variables to be plotted
    # Cols: number of x_axis parameter values 
    shape = (len(final_paths), len(x_axis))
    # print(shape)

    # Initialize data sequences
    max_latency_per_query = [[None for col in range(0,shape[1])] 
                            for row in range(0,shape[0])]
    means = np.ndarray(shape=shape)
    means_99 = np.ndarray(shape=shape)



    for path_num, path in enumerate(final_paths):
        queue_data_list, queue_trace_list = load_files(path_num, path, 
            final_file_ids[path_num], x_axis, max_latency_per_query, means, means_99)
        plot_queue_size(queue_data_list, path, x_axis, out_folder_name)
        plot_queue_trace(queue_trace_list, path, x_axis, out_folder_name)
    #Create mean_latency - x_axis graph
    # print(means)
    plot_mean_lat_vs_xaxis(shape, final_paths, final_file_ids, x_axis, means,
            means_99, x_axis_title, out_folder_name, log_y=False, plot_mean=False, plot_99=True)
    plot_mean_lat_vs_xaxis(shape, final_paths, final_file_ids, x_axis, means,
            means_99, x_axis_title, out_folder_name, log_y=True, plot_mean=False, plot_99=True)


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

def plot_queue_size(list_of_data, path, x_axis, out_folder_name):
    for i, data in enumerate(list_of_data):
        fig, ax = plt.subplots(nrows=1, ncols=1, figsize=(20,10))
        label = path
        # http://www.mathcs.emory.edu/~cheung/Courses/558-old/Syllabus/90-NS/trace.html
        # Columns are: Time(s)-fromNode-toNode-SizeB-SizePack-Packsarrived(in interval)
        # -departed - dropped -3: same in bytes
        times = data[:,0]
        q_size_B = data[:,3]
        q_size_B = np.trim_zeros(q_size_B, trim='b')
        times = times[:q_size_B.shape[0]]
        q_size_B = np.trim_zeros(q_size_B, trim='f')
        times = times[times.shape[0] - q_size_B.shape[0]:]

        ax.plot(times, q_size_B, label="q_size in bytes "+label) 
        ax.set_title("Q size vs Time")
        ax.legend(loc='upper left')
        ax.set_ylabel('Bytes')
        ax.set_xlabel('Seconds')
        ax.grid(which='major', linestyle="-")
        ax.grid(which='minor', linestyle='--')
        plt.minorticks_on()

        #ax.set_xlim(left=x_axis[0], right=x_axis[len(x_axis)-1])
        #ax.set_ylim(bottom=0)
        storage_folder = "plots/"+out_folder_name+"/Q/"+path.split("/")[-1]
        fig.tight_layout()   
        try:
            os.makedirs(storage_folder)
        except FileExistsError:
            "Plots file already exists"

        fig.savefig(storage_folder+"/Q_size vs Time_"+str(x_axis[i])+".png", format="png")

        avg_q_occup = np.mean(q_size_B)
        print("Mon_mean: " + str(avg_q_occup) + "  " + path + " x: " + str(x_axis[i]))




def plot_queue_trace(list_of_data, path, x_axis, out_folder_name):
    for i, data in enumerate(list_of_data):
        fig, ax = plt.subplots(nrows=1, ncols=1, figsize=(20,10))
        label = path
        # http://www.mathcs.emory.edu/~cheung/Courses/558-old/Syllabus/90-NS/trace.html
        # Columns are: Time(s)-fromNode-toNode-SizeB-SizePack-Packsarrived(in interval)
        # -departed - dropped -3: same in bytes
        cond = lambda tup: tup[0] == 'Q'
        #current_data = np.array([cond(tup) for tup in data])
        current_data = np.array(list(filter(cond, data)))
        # THIS IS SLOW
        times = np.array([x[1] for x in current_data])
        q_size_B = np.array([x[2] for x in current_data])

        ax.plot(times, q_size_B, label="q_size in bytes "+label) 
        ax.set_title("Q size vs Time(events)")
        ax.legend(loc='upper left')
        ax.set_ylabel('Bytes')
        ax.set_xlabel('Seconds')
        ax.grid(which='major', linestyle="-")
        ax.grid(which='minor', linestyle='--')
        plt.minorticks_on()

        #ax.set_xlim(left=x_axis[0], right=x_axis[len(x_axis)-1])
        #ax.set_ylim(bottom=0)
        storage_folder = "plots/"+out_folder_name+"/Q/"+path.split("/")[-1]
        fig.tight_layout()   
        try:
            os.makedirs(storage_folder)
        except FileExistsError:
            "Plots file already exists"

        fig.savefig(storage_folder+"/Q_TRACE vs Time_"+str(x_axis[i])+".png", format="png")
        avg_q_occup = np.mean(q_size_B)
        print("TR_mean: " + str(avg_q_occup) + "  " + path + " x: " +str(x_axis[i]))
        #print("----------")


def plot_mean_lat_vs_xaxis(shape, paths, final_file_ids, x_axis, means, means_99, x_axis_title,
                            out_folder_name, log_y=False, plot_mean=True, plot_99=True):
    #Create mean_latency - x_axis graph
    markers = ["o","v","1","s","p","P","*","x"]
    fig, ax = plt.subplots(nrows=1, ncols=1, figsize=(20,10))
    for i in range(shape[0]):
        label = paths[i].split("/")[-1] + " Workload:" + final_file_ids[i]
        if log_y:
            if plot_mean:
                ax.semilogy(x_axis, means[i]*1000.0, label="mean "+label, 
                        marker=markers[i%len(markers)]) 
            if plot_99:
                ax.semilogy(x_axis, means_99[i]*1000.0, ':', label="99th% "+label, 
                        marker=markers[i%len(markers)])         
        else:
            if plot_mean:
                ax.plot(x_axis, means[i]*1000.0, label="mean "+label, 
                        marker=markers[i%len(markers)]) 
            if plot_99:
                ax.plot(x_axis, means_99[i]*1000.0, ':', label="99th% "+label, 
                        marker=markers[i%len(markers)])     
    
    ax.set_title("Average Latency vs " + x_axis_title)
    ax.legend(loc='upper left')
    ax.set_ylabel('miliseconds')
    ax.set_xlabel(x_axis_title)
    ax.grid(which='major', linestyle="-")
    ax.grid(which='minor', linestyle='--')
    plt.minorticks_on()

    ax.set_xlim(left=x_axis[0], right=x_axis[len(x_axis)-1])
    if not log_y:
        ax.set_ylim(bottom=0)
    fig.tight_layout()   
    try:
        os.makedirs("plots/"+out_folder_name)
    except FileExistsError:
        "Plots file already exists"

    if log_y:
        fig.savefig("plots/"+out_folder_name+"/Latency_vs_"+x_axis_title+"|logY.png", format="png")
    else:
        fig.savefig("plots/"+out_folder_name+"/Latency_vs_"+x_axis_title+".png", format="png")



def load_files(file_num, path, file_id, x_axis, max_latency_per_query, means, means_99):
    q_size_data_list = []
    q_size_data_trace_list = []
    for i, x_val in enumerate(x_axis):
        snd_file_path = path+"/send_timesload"+str(x_val)+"|wkld"+str(file_id)+".csv"
        rec_file_path = path+"/rec_timesload"+str(x_val)+"|wkld"+str(file_id)+".csv"
        tmp_send_times = np.genfromtxt(snd_file_path, delimiter=",")
        tmp_receive_times = np.genfromtxt(rec_file_path, delimiter=",")
        tmp_q = np.genfromtxt(path+"/q_mon_"+str(x_val), delimiter=" ")
        if "DCTCP_K0" not in path:
            tmp_q_trace = np.genfromtxt(path+"/trace_q_"+str(x_val), delimiter=" ",
                                        encoding=None, dtype=None)


        
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
        q_size_data_list.append(tmp_q)
        if "DCTCP_K0" not in path:
            q_size_data_trace_list.append(tmp_q_trace)
    return q_size_data_list, q_size_data_trace_list

if __name__ == "__main__":
    main()

