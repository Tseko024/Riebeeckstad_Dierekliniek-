import 'package:flutter/material.dart';

class ClinicService {
  const ClinicService({
    required this.title,
    required this.blurb,
    required this.details,
    required this.icon,
    required this.bookingValue,
  });

  final String title;
  final String blurb;
  final String details;
  final IconData icon;
  final String bookingValue;
}

const clinicServices = <ClinicService>[
  ClinicService(
    title: 'General Checkup',
    blurb: 'Routine exams to keep your pet healthy.',
    details:
        'A full nose-to-tail examination: weight, heart and lungs, eyes, ears, '
        'skin and coat. Ideal once a year, or whenever your pet seems unwell.',
    icon: Icons.medical_services_outlined,
    bookingValue: 'general_checkup',
  ),
  ClinicService(
    title: 'Vaccination',
    blurb: 'Essential vaccines for a healthier future.',
    details:
        'Puppy and kitten courses, annual boosters and rabies vaccinations, '
        'with a reminder of when the next dose is due.',
    icon: Icons.vaccines,
    bookingValue: 'vaccination',
  ),
  ClinicService(
    title: 'Surgery',
    blurb: 'Safe and professional surgical procedures.',
    details:
        'Sterilisations, lump removals, wound repairs and other procedures, '
        'performed under anaesthetic with careful monitoring.',
    icon: Icons.healing,
    bookingValue: 'surgery',
  ),
  ClinicService(
    title: 'Dental Care',
    blurb: 'Keep their teeth clean and strong.',
    details: 'Dental checks, scale and polish, and extractions where needed. '
        'Bad breath is often the first sign of dental disease.',
    icon: Icons.sentiment_satisfied_alt,
    bookingValue: 'dental',
  ),
  ClinicService(
    title: 'Parasite Control',
    blurb: 'Protection from fleas, ticks and worms.',
    details:
        'Advice and treatment plans for fleas, ticks and intestinal worms, '
        'suited to your pet\'s age, size and lifestyle.',
    icon: Icons.bug_report_outlined,
    bookingValue: 'other',
  ),
  ClinicService(
    title: 'Diagnostic Services',
    blurb: 'X-rays, blood tests and more.',
    details: 'In-house blood tests, X-rays and other diagnostics to find out '
        'what is wrong quickly and plan the right treatment.',
    icon: Icons.monitor_heart_outlined,
    bookingValue: 'other',
  ),
  ClinicService(
    title: 'Grooming',
    blurb: 'Professional grooming to keep them looking great.',
    details: 'Washing, brushing, nail clipping and coat care to keep your pet '
        'comfortable and healthy.',
    icon: Icons.content_cut,
    bookingValue: 'other',
  ),
  ClinicService(
    title: 'Pet Nutrition Advice',
    blurb: 'Guidance on the best nutrition for your pet.',
    details:
        'Diet plans for weight control, allergies, growing puppies and kittens, '
        'and older pets.',
    icon: Icons.restaurant,
    bookingValue: 'other',
  ),
  ClinicService(
    title: 'Pet Essentials',
    blurb: 'Quality foods, treats and pet care products.',
    details:
        'Prescription and premium foods, treats, flea and tick products and '
        'other essentials are available at the clinic.',
    icon: Icons.shopping_cart_outlined,
    bookingValue: 'other',
  ),
];
