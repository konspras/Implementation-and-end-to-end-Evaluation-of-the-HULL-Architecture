/* -*-	Mode:C++; c-basic-offset:8; tab-width:8; indent-tabs-mode:t -*- */
/*
 * Copyright (c) 1996-1997 The Regents of the University of California.
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 * 	This product includes software developed by the Network Research
 * 	Group at Lawrence Berkeley National Laboratory.
 * 4. Neither the name of the University nor of the Laboratory may be used
 *    to endorse or promote products derived from this software without
 *    specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef lint
static const char rcsid[] =
    "@(#) $Header: /cvsroot/nsnam/ns-2/link/delay.cc,v 1.28 2005/07/13 03:51:25 tomh Exp $ (LBL)";
#endif

#include "delay.h"
#include "mcast_ctrl.h"
#include "ctrMcast.h"

static class LinkDelayClass : public TclClass {
public:
	LinkDelayClass() : TclClass("DelayLink") {}
	TclObject* create(int /* argc */, const char*const* /* argv */) {
		return (new LinkDelay);
	}
} class_delay_link;

LinkDelay::LinkDelay() 
	: dynamic_(0), 
	  latest_time_(0),
	  itq_(0),
	  PQ_current_q_util_(0),
	  has_PQ_(0)
{
	printf("LinkDelay::LinkDelay\n");
	bind_bw("bandwidth_", &bandwidth_);
	bind_time("delay_", &delay_);
	bind_bool("avoidReordering_", &avoidReordering_);
}

int LinkDelay::command(int argc, const char*const* argv)
{
	printf("LinkDelay::command. argc: %d\n", argc);
	if (argc == 2) {
		if (strcmp(argv[1], "isDynamic") == 0) {
			printf("it is dynamic_\n");
			dynamic_ = 1;
			itq_ = new PacketQueue();
			return TCL_OK;
		} else if (strcmp(argv[1], "hasPQ") == 0) {
			printf("HAS PQ!\n");
			has_PQ_ = 1;
			return TCL_OK;
		}
	} else if (argc == 6) {
		if (strcmp(argv[1], "pktintran") == 0) {
			int src = atoi(argv[2]);
			int grp = atoi(argv[3]);
			int from = atoi(argv[4]);
			int to = atoi(argv[5]);
			pktintran (src, grp);
			Tcl::instance().evalf("%s puttrace %d %d %d %d %d %d %d %d", name(), total_[0], total_[1], total_[2], total_[3], src, grp, from, to);
			return TCL_OK;
		}
	}

	return Connector::command(argc, argv);
}

void LinkDelay::recv(Packet* p, Handler* h)
{
	printf("LinkDelay::recv at time %f. Has PQ?: %d\n", Scheduler::instance().clock(), has_PQ_);
	double txt = txtime(p);
	
	if (has_PQ_) {
		double now_ = Scheduler::instance().clock();		
		double elapsed_time = now_ - latest_time_;
		// Decrease PQ_util based on the reduced BW and the elapsed time.
		long bytes_sent = ((bandwidth_ * PQ_drain_rate_) * elapsed_time)/8.0; //bits/8
		PQ_current_q_util_ -= bytes_sent;
		if(PQ_current_q_util_ < 0) 
			PQ_current_q_util_ = 0.0;
 		// Add the rcved packet's size to the PQ
		PQ_current_q_util_ += hdr_cmn::access(p)->size();
 		
 		// Check if queue size exceeds threshold. If so, mark CE
 		if(PQ_current_q_util_ > PQ_thresh_){
 			printf("MARK EC\n");
 		}
 		latest_time_ = now_ + txt + delay_;
		printf("CURRENT PQ Size: %f\n",PQ_current_q_util_);	
	}
	
	Scheduler& s = Scheduler::instance();
	if (dynamic_) {
		printf("isDynamic\n");
		Event* e = (Event*)p;
		e->time_= txt + delay_;
		itq_->enque(p); // for convinience, use a queue to store packets in transit
		s.schedule(this, p, txt + delay_);
	} else if (avoidReordering_) {
		printf("avoidReordering_\n");
		// code from Andrei Gurtov, to prevent reordering on
		//   bandwidth or delay changes
 		double now_ = Scheduler::instance().clock();
 		if (txt + delay_ < latest_time_ - now_ && latest_time_ > 0) {
 			latest_time_+=txt;
 			s.schedule(target_, p, latest_time_ - now_ );
 		} else {
 			latest_time_ = now_ + txt + delay_;
 			s.schedule(target_, p, txt + delay_);
 		}

	} else {
		printf("Scheduling for %f\n", txt + delay_);
		// Pass to downstream objetc (TTL?). will invoke recv(p) of dnstrm obj
		s.schedule(target_, p, txt + delay_);
	}
	// Inform upstream object (queue?) of packet departure so that it can send
	// another one..
	s.schedule(h, &intr_, txt);
}

void LinkDelay::send(Packet* p, Handler*)
{
	printf("LinkDelay::send\n");
	target_->recv(p, (Handler*) NULL);
}

void LinkDelay::reset()
{
	printf("LinkDelay::reset\n");
	Scheduler& s= Scheduler::instance();

	if (itq_ && itq_->length()) {
		Packet *np;
		// walk through packets currently in transit and kill 'em
		while ((np = itq_->deque()) != 0) {
			s.cancel(np);
			drop(np);
		}
	}
}

void LinkDelay::handle(Event* e)
{
	printf("LinkDelay::handle\n");
	Packet *p = itq_->deque();
	assert(p->time_ == e->time_);
	send(p, (Handler*) NULL);
}

void LinkDelay::pktintran(int src, int group)
{
	printf("LinkDelay::pktintran\n");
	int reg = 1;
	int prune = 30;
	int graft = 31;
	int data = 0;
	for (int i=0; i<4; i++) {
		total_[i] = 0;
	}

	if (! dynamic_)
		return;

	int len = itq_->length();
	while (len) {
		len--;
		Packet* p = itq_->lookup(len);
		hdr_ip* iph = hdr_ip::access(p);
		if (iph->flowid() == prune) {
			if (iph->saddr() == src && iph->daddr() == group) {
				total_[0]++;
			}
		} else if (iph->flowid() == graft) {
			if (iph->saddr() == src && iph->daddr() == group) {
				total_[1]++;
			}
		} else if (iph->flowid() == reg) {
			hdr_CtrMcast* ch = hdr_CtrMcast::access(p);
			if (ch->src() == src+1 && ch->group() == group) {
				total_[2]++;
			}
		} else if (iph->flowid() == data) {
			if (iph->saddr() == src+1 && iph->daddr() == group) {
				total_[3]++;
			}
		}
	}
        //printf ("%f %d %d %d %d\n", Scheduler::instance().clock(), total_[0], total_[1], total_[2],total_[3]);
}
