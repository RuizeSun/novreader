import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/subject.dart';

/// A card widget used only on the Bookshelf page to display a Bangumi subject.
/// It is separate from the generic `SubjectCard` to avoid affecting other pages.
class BookshelfItemCard extends StatelessWidget {
  final Subject subject;
  final VoidCallback? onTap;

  const BookshelfItemCard({Key? key, required this.subject, this.onTap})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fixed height image to avoid unbounded constraints inside ListView
            SizedBox(
              height: 200,
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: Hero(
                  tag: 'bookshelf-${subject.id}',
                  child: subject.images.medium.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: subject.images.medium,
                          fit: BoxFit.cover,
                          placeholder: (c, u) => Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (c, u, e) => Container(
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.broken_image,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.menu_book,
                            color: Colors.grey,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              child: Text(
                subject.nameCn.isNotEmpty ? subject.nameCn : subject.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              child: Row(
                children: [
                  Icon(Icons.star, size: 12, color: Colors.amber[700]),
                  const SizedBox(width: 2),
                  Text(
                    subject.rating.score.toString(),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${subject.collectionsCount}人收藏',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
