/* -*-	Mode:C++; c-basic-offset:8; tab-width:8; indent-tabs-mode:t -*- */
/*
 * Copyright (c) Xerox Corporation 1997. All rights reserved.
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 *
 * Linking this file statically or dynamically with other modules is making
 * a combined work based on this file.  Thus, the terms and conditions of
 * the GNU General Public License cover the whole combination.
 *
 * In addition, as a special exception, the copyright holders of this file
 * give you permission to combine this file with free software programs or
 * libraries that are released under the GNU LGPL and with code included in
 * the standard release of ns-2 under the Apache 2.0 license or under
 * otherwise-compatible licenses with advertising requirements (or modified
 * versions of such code, with unchanged license).  You may copy and
 * distribute such a system following the terms of the GNU GPL for this
 * file and the licenses of the other code concerned, provided that you
 * include the source code of that other code when and as the GNU GPL
 * requires distribution of source code.
 *
 * Note that people who make modified versions of this file are not
 * obligated to grant this special exception for their modified versions;
 * it is their choice whether to do so.  The GNU General Public License
 * gives permission to release a modified version without this exception;
 * this exception also makes it possible to release a modified version
 * which carries forward this exception.
 */

/* Token Bucket filter which has  3 parameters :
   a. Token Generation rate
   b. Token bucket depth
   c. Max. Queue Length (a finite length would allow this to be used as  policer as packets are dropped after queue gets full)
   Based on adc/tbf
   */

#include <cstdlib>
#include "connector.h" 
#include "packet.h"
#include "queue.h"
#include "hull-pacer.h"

HullPacer::HullPacer() :
	tokens_(0),
	eta_(0.125),
	beta_(16),
	bits_since_rt_upd_(0),
	q_length_bits_(0),
	token_upd_interval_(0.000016),
	rate_upd_interval_(0.000064),
	hptbf_timer_(this),
	rate_timer_(this),
	token_timer_(this),
	init_(1),
	deassoc_time_(0.01),
	p_assoc_(0.125),
	debug_(0),
	verbose_(0),
	num_flows_(0)
{
	q_ = new PacketQueue();
	std::srand(1);
	// in bps
	bind_bw("rate_",&rate_);
	// Bucket is in bits
	bind("bucket_",&bucket_);
	// qlen is in packets
	bind("qlen_",&qlen_);
	// in seconds
	bind("rate_upd_interval_",&rate_upd_interval_);
	bind("eta_",&eta_);
	bind("beta_",&beta_);
	bind("p_assoc_",&p_assoc_);
	bind("deassoc_time_",&deassoc_time_);
	bind("debug_",&debug_);
	bind("verbose_",&verbose_);
	bind("num_flows_",&num_flows_);

	for (int i=0; i<500; i++){
		flow_assoc_[i] = 0;
		Flow_Deassoc_Timer* ptr = new Flow_Deassoc_Timer(this, i);
		times_assoc_[i] = 0;
		times_deassoc_[i] = 0;
		flow_assoc_timer_[i] = ptr;
	}
	
}
	
HullPacer::~HullPacer()
{
	if (q_->length() != 0) {
		//Clear all pending timers
		hptbf_timer_.cancel();
		rate_timer_.cancel();
		token_timer_.cancel();
		//Free up the packetqueue
		for (Packet *p=q_->head();p!=0;p=p->next_) 
			Packet::free(p);
	}
	delete q_;
	for (int i=0; i<500; i++){
		delete flow_assoc_timer_[i];
	}
}


void HullPacer::recv(Packet *p, Handler *h)
{
	if (init_) {
		getupdatedrate();
		getupdatedtokens();
		tokens_ = bucket_;
		init_=0;
	}
	//printf("%d  %f\n", debug_, rate_upd_interval_);
	h_ = h;
	hdr_cmn *ch = hdr_cmn::access(p);
	int pktsize = ch->size()<<3;
	bits_since_rt_upd_ += pktsize;
	hdr_ip *iph = hdr_ip::access(p);
	int this_flow = iph->flowid();
	if(verbose_==1){
		printf("--------------------------------------------------------------\n");
		printf("%f TBF::recv (%d bytes) from flow: (%d). Current Q in pkts is %d\n", Scheduler::instance().clock(), pktsize/8, iph->flowid(), q_->length());
		printf("Current rate (Mbbps) is: %f, current token level (Bytes):%f\n",rate_/1000000.0, tokens_/8.0 );
		printf("Source addr: %d\n", iph->saddr());
		printf("Dst addr: %d\n", iph->daddr());
		printf("Source port: %d\n", iph->sport());
		printf("Dst port: %d\n", iph->dport());
		printf("Associated:\n");
		for(int i = 0; i<num_flows_; i++){
			printf("(%d,%d)", i, times_assoc_[i]);
		}
		printf("\nDeassociated:\n");
		for(int i = 0; i<num_flows_; i++){
			printf("(%d,%d)", i, times_deassoc_[i]);
		}
		printf("\n");
	}
	
	
	//hdr_tcp *tcph = hdr_tcp::access(p);
	int gotecho = iph->gotecnecho;
	if(gotecho) {
		double rand_num = (double) std::rand();
		if(rand_num/RAND_MAX <= p_assoc_){
			if(verbose_){
				printf("Flow Associated\n");
			}
			flow_assoc_[this_flow] = 1;
			times_assoc_[this_flow] += 1;
			flow_assoc_timer_[this_flow]->resched(deassoc_time_);
		}

	}

	// if the flow is not associated just forward the packet
	if(flow_assoc_[this_flow] == 0){
		if(verbose_){
			printf("Send immediately - non-associated\n");
		}
		send(p,h_);
		return;
	}

	// since the flow is associated, enque packets 
	// appropriately if a non-zero q already exists
	if (q_->length() != 0) {
		if(verbose_){
			printf("Queue is not empty, enqueue\n");
		}
		if (q_->length() < qlen_) {
			q_->enque(p);
			q_length_bits_ += pktsize;
			return;
		}
		if(verbose_){
			printf("Queue is full, drop\n");
		}
		drop(p);
		return;
	}

	// If there are enough tokens...
	if (tokens_ >= pktsize) {
		if(verbose_){
			printf("Sending immediately - ASSOC\n");
		}
		send(p,h_);
		tokens_-=pktsize;
	}

	// else if there are not enough tokens, enqueue and resched for when
	// there will be.
	else {
		
		if (qlen_!=0) {
			q_->enque(p);
			if(verbose_){
				double now=Scheduler::instance().clock();
				printf("Scheduling packet for when there are tokens. Curr Q len is %d\n", q_->length());
				printf("At %f\n", now+(pktsize-tokens_)/rate_);
			}
			q_length_bits_ += pktsize;
			hptbf_timer_.resched((pktsize-tokens_)/rate_);
		}
		else {
			if(verbose_){
				printf("There is no queue, drop\n");
			}
			drop(p);
		}
	}
}

double HullPacer::getupdatedtokens(void)
{
	tokens_ += (token_upd_interval_)*rate_;
	if (tokens_ > bucket_)
		tokens_ = bucket_;
	token_timer_.resched(token_upd_interval_);
	return tokens_;
}

double HullPacer::getupdatedrate(void)
{
	// rate is in bits/s
	rate_ = (1.0-eta_)*rate_ + eta_*(bits_since_rt_upd_/rate_upd_interval_)
			 + beta_*(q_length_bits_);
	bits_since_rt_upd_ = 0.0;
	rate_timer_.resched(rate_upd_interval_);

	// added this beacuse if the rate is close to 0, a queued packet might be scheduled 
	// long into the future.
	if (q_->length() !=0 ) {
		Packet *p=q_->head();
		hdr_cmn *ch=hdr_cmn::access(p);
		int pktsize = ch->size()<<3;
		if (tokens_ > pktsize) {
			hptbf_timer_.resched(0.0);
		} else {
			hptbf_timer_.resched((pktsize-tokens_)/rate_);
		}
	}
	return rate_;
}

void HullPacer::de_associate_flow(int flow_id)
{
	flow_assoc_[flow_id] = 0;
	times_deassoc_[flow_id] += 1;
}

void HullPacer::timeout(int)
{

	if (q_->length() == 0) {
		fprintf (stderr,"ERROR in tbf\n");
		abort();
	}
	
	Packet *p=q_->deque();
	hdr_cmn *ch=hdr_cmn::access(p);
	int pktsize = ch->size()<<3;
	q_length_bits_ -= pktsize;

	send(p, h_);
	tokens_-=pktsize;

	if (q_->length() !=0 ) {
		p=q_->head();
		hdr_cmn *ch=hdr_cmn::access(p);
		pktsize = ch->size()<<3;
		hptbf_timer_.resched((pktsize-tokens_)/rate_);
	}
}

void HPTBF_Timer::expire(Event* /*e*/)
{
	hp_->timeout(0);
}

void Rate_Update_Timer::expire(Event* /*e*/)
{
	hp_->getupdatedrate();
}

void Token_Update_Timer::expire(Event* /*e*/)
{
	hp_->getupdatedtokens();
}

void Flow_Deassoc_Timer::expire(Event* /*e*/)
{
	hp_->de_associate_flow(this->flow_);
}


static class HullPacerClass : public TclClass {
public:
	HullPacerClass() : TclClass ("HullPacer") {}
	TclObject* create(int,const char*const*) {
		return (new HullPacer());
	}
}class_HullPacer;
