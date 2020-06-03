package org.schabi.newpipe.util;

import java.util.concurrent.TimeUnit;

import static org.schabi.newpipe.extractor.ServiceList.SoundCloud;

public class ServiceHelper {
	public static long getCacheExpirationMillis(final int serviceId) {
		if (serviceId == SoundCloud.getServiceId()) {
			return TimeUnit.MILLISECONDS.convert(5, TimeUnit.MINUTES);
		} else {
			return TimeUnit.MILLISECONDS.convert(1, TimeUnit.HOURS);
		}
	}
}
