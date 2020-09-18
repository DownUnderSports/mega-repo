import React, { Component } from 'react';

const categories = {
  i: 'Information',
  f: 'Fundraising',
  d: 'Departure',
  s: 'Staff',
  a: 'Athlete',
  p: 'Parent/Guardian',
}

export default class VideosPage extends Component {
  render() {
    const { match: { params: { category = 'i' } } } = this.props,
          formatted = `${category}`.toLowerCase()[0],
          categoryTitle = categories[formatted]

    return (
      <section className='VideosPage my-4'>
        <header className='mb-4'>
          <h3>
            View { categoryTitle || categories.i } Video
          </h3>
        </header>
        <div className="main">
          <p class="text-center">
            Our Video Player is temporarily disabled while Down Under Sports
            handles the COVID-19 pandemic. Please contact our office using the
            information provided below for more assistance.
          </p>
        </div>
      </section>
    );
  }
}
