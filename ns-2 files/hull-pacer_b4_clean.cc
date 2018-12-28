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
	p_assoc_(0.125)
{
	q_ = new PacketQueue();
	std::srand(1);
	// in bps
	bind_bw("rate_",&rate_);
	// Bucket is in bits
	bind("bucket_",&bucket_);
	// qlen is in packets
	bind("qlen_",&qlen_);
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
		//lastupdatetime_ = Scheduler::instance().clock();
		init_=0;
	}

	h_ = h;
	hdr_cmn *ch = hdr_cmn::access(p);
	int pktsize = ch->size()<<3;
	bits_since_rt_upd_ += pktsize;
	hdr_ip *iph = hdr_ip::access(p);
	int this_flow = iph->flowid();
	//printf("%f TBF::recv (%d bytes) from flow: (%d). Current Q in pkts is %d\n", Scheduler::instance().clock(), pktsize/8, iph->flowid(), q_->length());
	//printf("Current rate (Mbbps) is: %f, current token level (Bytes):%f\n",rate_/8.0/1000000.0, tokens_/8.0 );

	//start with a full bucket
	//printf("---------------------------------------\n");
	// 	printf("%f TBF::recv (%d bytes) from flow: (%d). Current Q in pkts is %d\n", Scheduler::instance().clock(), pktsize/8, iph->flowid(), q_->length());
	// 	printf("Current rate (Mbbps) is: %f, current token level (Bytes):%f\n",rate_/8.0/1000000.0, tokens_/8.0 );
	// }
	
	//double now_ = Scheduler::instance().clock();
	//hdr_tcp *tcph = hdr_tcp::access(p);
	int gotecho = iph->gotecnecho;
	if(gotecho) {
		double rand_num = (double) std::rand();
		if(rand_num/RAND_MAX <= p_assoc_){
			//printf("%f TBF::recv (%d bytes) from flow: (%d). Current Q in pkts is %d\n", Scheduler::instance().clock(), pktsize/8, iph->flowid(), q_->length());
		 	//printf("Current rate (Mbbps) is: %f, current token level (Bytes):%f\n",rate_/8.0/1000000.0, tokens_/8.0 );

			flow_assoc_[this_flow] = 1;
			times_assoc_[this_flow] += 1;
			flow_assoc_timer_[this_flow]->resched(deassoc_time_);
			// for (int i=0;i<40;i++){
			// 	printf("%d,",times_assoc_[i]);
			// }
			// printf("\n");
			// for (int i=0;i<40;i++){
			// 	printf("%d,",times_deassoc_[i]);
			// }
			// printf("\n");
			// schedule reset
			// also make sure to not set and reschedule if already set? Maybe?
			// not clear
		}

	}

	// if the flow is not associated just forward the packet
	if(flow_assoc_[this_flow] == 0){
		send(p,h_);
		return;
	}
	//printf("Source addr: %d\n", iph->saddr());
	//printf("Dst addr: %d\n", iph->daddr());
	//printf("Source port: %d\n", iph->sport());
	//printf("Dst port: %d\n", iph->dport());



	// since the flow is associated, enque packets 
	// appropriately if a non-zero q already exists
	if (q_->length() != 0) {
		printf("ENQUEUE\n");
		if (q_->length() < qlen_) {
			q_->enque(p);
			q_length_bits_ += pktsize;
			return;
		}
		printf("DROOOOOOOOP\n");
		drop(p);
		return;
	}

	// This will be happening asyncronously
	// double tok;
	// tok = getupdatedtokens();
	//printf("Tokens currently available: %f\n", tok);

	//printf("ch->size (B) is: %d\n", ch->size());
	//printf("pktsize in bits is:%d\n", pktsize);

	//Scheduler& s = Scheduler::instance();
	// If there are enough tokens...
	if (tokens_ >= pktsize) {
		//printf("Send NOW\n");
		//printf("Target == %d\n", target_);
		//if (target_ == NULL) printf("TARGET IS NULL\n");
		//else printf("NOT NULL\n");
		send(p,h_);
		//s.schedule(target_, p, 0);
		//target_->recv(p, (Handler*) NULL);
		tokens_-=pktsize;
	}
	// else if there are not enough tokens, enqueue and resched for when
	// there will be.
	else {
		//printf("Don't have enough tokens\n");
		if (qlen_!=0) {
			q_->enque(p);
			q_length_bits_ += pktsize;
			//printf("resched for: %f\n", now_+(pktsize-tokens_)/rate_);
			hptbf_timer_.resched((pktsize-tokens_)/rate_);
		}
		else {
			printf("DROOOOOOOOP\n");
			drop(p);
		}
	}
}

double HullPacer::getupdatedtokens(void)
{
	//printf("TBF::getupdatedtokens\n");
	//double now=Scheduler::instance().clock();
	// tokens in bits (rate is bits/s)
	tokens_ += (token_upd_interval_)*rate_;
	if (tokens_ > bucket_)
		tokens_ = bucket_;
	//lastupdatetime_ = Scheduler::instance().clock();
	token_timer_.resched(token_upd_interval_);
	// 	printf("tokens = %f", tokens_);
	// }
	return tokens_;
}

double HullPacer::getupdatedrate(void)
{
	//printf("TBF::getupdatedtokens\n");
	//double now=Scheduler::instance().clock();
	// rate is in bits/s
	rate_ = (1.0-eta_)*rate_ + eta_*(bits_since_rt_upd_/rate_upd_interval_)
			 + beta_*(q_length_bits_);
	bits_since_rt_upd_ = 0.0;
	rate_timer_.resched(rate_upd_interval_);
	// 	printf("rate = %f", rate_);
		// }
	return rate_;
}

void HullPacer::de_associate_flow(int flow_id)
{
	//printf("===== at: %f: de-associate called for flow: %d\n", Scheduler::instance().clock(),flow_id);
	flow_assoc_[flow_id] = 0;
	times_deassoc_[flow_id] += 1;
}

void HullPacer::timeout(int)
{
	//printf("===> %f TBF::timeout\n", Scheduler::instance().clock());

	if (q_->length() == 0) {
		fprintf (stderr,"ERROR in tbf\n");
		abort();
	}
	
	Packet *p=q_->deque();
	hdr_cmn *ch=hdr_cmn::access(p);
	int pktsize = ch->size()<<3;
	q_length_bits_ -= pktsize;
	// this will be happening asynchr
	// double tok;
	// tok = getupdatedtokens();

	//We simply send the packet here without checking if we have enough tokens
	//because the timer is supposed to fire at the right time
	// Scheduler& s = Scheduler::instance();
	// s.schedule(target_, p, 0);
	//target_->recv(p, (Handler*) NULL);
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
	//printf("%f TBF_Timer::expire\n", Scheduler::instance().clock());
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
