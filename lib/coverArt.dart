import 'package:flutter/material.dart';

import 'package:cached_network_image/cached_network_image.dart';

import 'cacheManager.dart';
import 'data.dart';

Widget coverArt({@required CoverArtData mainArt, CoverArtData backupArt, @required double size}) {
  return CachedNetworkImage(
    imageUrl: mainArt.findSize(size).toString(),
    cacheManager: CustomCacheManager(),
    errorWidget: (context, url, stackTrace) => backupArt != null
        ? CachedNetworkImage(
            imageUrl: backupArt.findSize(size).toString(),
            cacheManager: CustomCacheManager(),
            errorWidget: (context, url, stackTrace) =>
                Icon(Icons.album, size: size, color: Colors.white70),
            fadeInDuration: Duration(milliseconds: 200),
            width: size,
            height: size,
          )
        : Icon(Icons.album, size: size, color: Colors.white70),
    fadeInDuration: Duration(milliseconds: 200),
    width: size,
    height: size,
  );
}
