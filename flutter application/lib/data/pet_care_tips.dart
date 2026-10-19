import 'package:flutter/material.dart';

class PetCareTip {
  const PetCareTip(this.title, this.body, this.icon);
  final String title;
  final String body;
  final IconData icon;
}

const petCareTips = <PetCareTip>[
  PetCareTip(
      'Good Nutrition',
      'Feed your pets a balanced diet suitable for their age, size and breed needs.',
      Icons.restaurant),
  PetCareTip(
      'Fresh Water',
      'Always make sure your pet has clean, fresh water available.',
      Icons.water_drop),
  PetCareTip(
      'Regular Exercise',
      'Keep your pets active with daily walks and playtime to maintain a healthy weight.',
      Icons.directions_run),
  PetCareTip(
      'Vaccination',
      "Keep your pet's vaccinations up to date to protect them from common diseases.",
      Icons.vaccines),
  PetCareTip(
      'Flea and Tick Control',
      'Use vet-recommended products to prevent fleas, ticks and other parasites.',
      Icons.bug_report),
  PetCareTip(
      'Regular Vet Check-ups',
      'Annual check-ups help detect health problems early and keep your pet happy and healthy.',
      Icons.medical_services),
];

PetCareTip tipOfTheDay() {
  final now = DateTime.now();
  final dayOfYear = now.difference(DateTime(now.year)).inDays;
  return petCareTips[dayOfYear % petCareTips.length];
}
