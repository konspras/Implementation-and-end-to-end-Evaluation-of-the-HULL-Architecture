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

#ifndef ns_hullpacer_h
#define ns_hullpacer_h

#include "connector.h"
#include "timer-handler.h"

class HullPacer;

class HPTBF_Timer : public TimerHandler {
public:
	HPTBF_Timer(HullPacer *t) : TimerHandler() { hp_ = t;}
	
protected:
	virtual void expire(Event *e);
	HullPacer *hp_;
};

class Rate_Update_Timer : public TimerHandler {
public:
	Rate_Update_Timer(HullPacer *t) : TimerHandler() { hp_ = t;}
	
protected:
	virtual void expire(Event *e);
	HullPacer *hp_;
};

class Token_Update_Timer : public TimerHandler {
public:
	Token_Update_Timer(HullPacer *t) : TimerHandler() { hp_ = t;}
	
protected:
	virtual void expire(Event *e);
	HullPacer *hp_;
};

class Flow_Deassoc_Timer : public TimerHandler {
public:
	Flow_Deassoc_Timer(HullPacer *t, int flow) : TimerHandler() { 
		hp_ = t;
		flow_ = flow;
	}
	
protected:
	virtual void expire(Event *e);
	HullPacer *hp_;
	int flow_;
};


class HullPacer : public Connector {
public:
	HullPacer();
	~HullPacer();
	void timeout(int);
	double getupdatedtokens();
	double getupdatedrate();
	void de_associate_flow(int);
protected:
	void recv(Packet *, Handler *);
	double tokens_; //acumulated tokens
	double rate_; //token bucket rate
	double eta_;
	double beta_;
	double bits_since_rt_upd_;
	double q_length_bits_;
	int bucket_; //bucket depth
	int qlen_;
	//double lastupdatetime_;
	double token_upd_interval_;
	double rate_upd_interval_;
	PacketQueue *q_;
	HPTBF_Timer hptbf_timer_;
	Rate_Update_Timer rate_timer_;
	Token_Update_Timer token_timer_;
	// TODO: generalize
	Flow_Deassoc_Timer* flow_assoc_timer_[500];
	int init_;
	// temporary and sketchy (because the handler is alw the same?)
	Handler *h_;
	// TODO: generalize
	int flow_assoc_ [500];
	int times_assoc_ [500];
	int times_deassoc_ [500];
	double deassoc_time_;
	double p_assoc_;
	int debug_;
	int verbose_;
	int num_flows_;
};

#endif
