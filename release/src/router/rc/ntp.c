/*
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston,
 * MA 02111-1307 USA
 *
 * Copyright 2004, ASUSTeK Inc.
 * All Rights Reserved.
 *
 * THIS SOFTWARE IS OFFERED "AS IS", AND ASUS GRANTS NO WARRANTIES OF ANY
 * KIND, EXPRESS OR IMPLIED, BY STATUTE, COMMUNICATION OR OTHERWISE. BROADCOM
 * SPECIFICALLY DISCLAIMS ANY IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS
 * FOR A SPECIFIC PURPOSE OR NONINFRINGEMENT CONCERNING THIS SOFTWARE.
 *
 */

#include <stdio.h>
#include <signal.h>
#include <time.h>
#include <sys/time.h>
#include <string.h>
#include <unistd.h>
#include <stdlib.h>
#include <sys/types.h>

#include <bcmnvram.h>
#include <shutils.h>
#include <rc.h>
#include <stdarg.h>

#define ZERO 0
#define SECONDS_TO_WAIT 5
#define NTP_RETRY_INTERVAL 30

static char server[32];
static int sig_cur = -1;
static int server_idx = 0;

static void ntp_service()
{
	static int first_sync = 1;
        // Don't set it only on first sync, someone else might have reset it
	if (!nvram_get_int("svc_ready"))
		nvram_set("svc_ready", "1");

	if (first_sync) {
		first_sync = 0;
		//nvram_set("ntp_sync", "0");
		nvram_set("reload_svc_radio", "1");

		setup_timezone();

		if (is_routing_enabled())
			notify_rc("restart_upnp");
#ifdef RTCONFIG_IPV6
		if (get_ipv6_service() != IPV6_DISABLED) {
			if ((getifaddr( (char *)get_wan6face(), AF_INET6, GIF_PREFIXLEN) ? : "") == "") { // only if ipv6 not already up
				if (get_ipv6_service() != IPV6_NATIVE_DHCP)
					notify_rc("restart_radvd");
				else
					notify_rc("restart_rdnssd");
			}
		}
#endif

#ifdef RTCONFIG_DISK_MONITOR
		notify_rc("restart_diskmon");
#endif

#if defined(RTCONFIG_DNSSEC)
		if (nvram_match("dnssec_enable", "1") && pids("dnsmasq")) {
			/* notify dnsmasq */
			kill_pidfile_s("/var/run/dnsmasq.pid", SIGINT);
		}
#endif

#ifdef RTCONFIG_DNSCRYPT
		if (nvram_match("dnscrypt_proxy", "1")) {
			/* restart dnscrypt to update timestamp check */
			restart_dnscrypt(0);
		}
#endif
#ifdef RTCONFIG_STUBBY
		if (nvram_match("stubby_proxy", "1")) {
			/* restart stubby to invoke TLS */
			restart_stubby(0);
		}
#endif
	}
}

static void catch_sig(int sig)
{
	sig_cur = sig;

	if (sig == SIGALRM)
	{
		/* no-op */
	}
	else if (sig == SIGTSTP)
	{
		ntp_service();
	}
	else if (sig == SIGTERM)
	{
		remove("/var/run/ntp.pid");
		exit(0);
	}
	else if (sig == SIGCHLD)
	{
		chld_reap(sig);
	}
}

static void set_alarm()
{
	struct tm local;
	time_t now;
	int diff_sec, user_hr;
	unsigned int sec;

	if (nvram_get_int("ntp_ready"))
	{
		/* ntp sync every hour when time_zone set as "DST" */
		if (strstr(nvram_safe_get("time_zone_x"), "DST") || nvram_match("ntp_force", "1")) {
			time(&now);
			localtime_r(&now, &local);
//			dbg("%s: %d-%d-%d, %d:%d:%d dst:%d\n", __FUNCTION__, local.tm_year+1900, local.tm_mon+1, local.tm_mday, local.tm_hour, local.tm_min, local.tm_sec, local.tm_isdst);
			/* every hour */
			if (((local.tm_min != 0) || (local.tm_sec != 0)) && nvram_match("ntp_force", "1")) {
				/* compensate for the alarm(SECONDS_TO_WAIT) */
				diff_sec = (3600 - SECONDS_TO_WAIT) - (local.tm_min * 60 + local.tm_sec);
				if (diff_sec == 0)
					diff_sec = 3600;
				else if (diff_sec < 0)
					diff_sec = 3600 - diff_sec;
				else if (diff_sec <= SECONDS_TO_WAIT)
					diff_sec += 3600;
//				dbg("diff_sec: %d \n", diff_sec);
				sec = diff_sec;
			}
			else
				sec = 3600 - SECONDS_TO_WAIT;
		}
		else	/* every 12 hours */
			sec = 12 * 3600 - SECONDS_TO_WAIT;

		user_hr = nvram_get_int("ntp_update");
		if (sec <= 3600 + SECONDS_TO_WAIT)
			sec = (user_hr ? (sec + ((user_hr - 1) * 3600)) : sec);
		else
			sec = (user_hr * 3600) - SECONDS_TO_WAIT;
	}
	else
		sec = NTP_RETRY_INTERVAL - SECONDS_TO_WAIT;

	//cprintf("## %s 4: sec(%u)\n", __func__, sec);
	alarm(sec);
}

int ntp_main(int argc, char *argv[])
{
	int attempts, tot_attempts, fflag;
	int i;
	FILE *fp;
	pid_t pid;
	char *args[] = {"ntpclient", "-h", server, "-i", "5", "-l", "-s", NULL};

	strlcpy(server, nvram_safe_get("ntp_server0"), sizeof(server));
	args[2] = server;

	fp = fopen("/var/run/ntp.pid", "w");
	if (fp == NULL)
		exit(0);
	fprintf(fp, "%d", getpid());
	fclose(fp);

	dbg("starting ntp...\n");

	signal(SIGTSTP, catch_sig);
	signal(SIGALRM, catch_sig);
	signal(SIGTERM, catch_sig);
//	signal(SIGCHLD, chld_reap);
	signal(SIGCHLD, catch_sig);

	attempts = 0;
	tot_attempts = 0;
	fflag = 0;
	nvram_set("ntp_ready", "0");
	nvram_set("svc_ready", "0");

	while (1)
	{
		if (nvram_get_int("ntp_update") == ZERO)
		{ //handle manual setting of time
			nvram_set("ntp_ready", "1");
			nvram_set("ntp_sync", "1");
			nvram_set("svc_ready", "1");
			nvram_set("ntp_server_tried", "none");
			stop_ntpc();
		}
		else if (sig_cur == SIGTSTP)
			;
		else if (nvram_get_int("sw_mode") == SW_MODE_ROUTER &&
			!nvram_match("link_internet", "1") && !nvram_get_int("ntp_force"))
		{
			alarm(SECONDS_TO_WAIT);
		}
		else if (sig_cur == SIGCHLD && nvram_get_int("ntp_ready") != 0 )
		{ //handle the delayed ntpclient process
			if ((nvram_match("ntp_log_x", "1") || fflag == 1) && tot_attempts != 0)
				logmessage("ntp", "NTP update successful after %d attempt(s)", tot_attempts);
			attempts = 0;
			tot_attempts = 0;
			fflag = 0;
			sleep(SECONDS_TO_WAIT);
			set_alarm();
		}
		else
		{ //make sure dnsmasq is up before starting update
			if (nvram_get_int("sw_mode") == SW_MODE_ROUTER) {
				for ( i = 1; i < 4; i++ ) {
					if (!pids("dnsmasq")) {
						logmessage("ntp", "waiting for dnsmasq...");
						sleep(i*i);
					} else {
						i = 99;
					}
				}
			}

			stop_ntpc();

			nvram_set("ntp_server_tried", server);
			nvram_set("ntp_ready", "0");
			if (nvram_match("ntp_log_x", "1") && tot_attempts == 0)
				logmessage("ntp", "start NTP update");
                        _eval(args, NULL, 0, &pid);
			sleep(SECONDS_TO_WAIT);

			/* handle syslog */
			attempts++;
			tot_attempts++;
			if (!nvram_get_int("ntp_ready")) {
				if (attempts % 5 == 0) {
					logmessage("ntp", "NTP update failed after %d attempts", attempts);
					attempts = 0;
					fflag = 1;
				}
			}
			else
			{
				if (nvram_match("ntp_log_x", "1") || fflag == 1)
					logmessage("ntp", "NTP update successful after %d attempt(s)", tot_attempts);
				attempts = 0;
				tot_attempts = 0;
				fflag = 0;
			}

			/* rotate servers */
			if (strlen(nvram_safe_get("ntp_server0")) && strlen(nvram_safe_get("ntp_server1")))
			{
				if (server_idx)
					strlcpy(server, nvram_safe_get("ntp_server1"), sizeof(server));
				else
					strlcpy(server, nvram_safe_get("ntp_server0"), sizeof(server));

				server_idx = (server_idx + 1) % 2;
			}
			else
			{
				if (strlen(nvram_safe_get("ntp_server0")))
				{
					strlcpy(server, nvram_safe_get("ntp_server0"), sizeof(server));
					server_idx = 0;
				}
				else if (strlen(nvram_safe_get("ntp_server1")))
				{
					strlcpy(server, nvram_safe_get("ntp_server1"), sizeof(server));
					server_idx = 1;
				}
				else
					strlcpy(server, "pool.ntp.org", sizeof(server));
			}
			args[2] = server;

			set_alarm();
		}

		pause();
	}
}
