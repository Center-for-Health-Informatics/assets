const Faces = new Map()

function setFace (id) {
  const face = Faces.get(id)
  if (face) {
    const F = new Set(Faces.keys())
    F.delete(id)
    for (const td of document.querySelectorAll('section#fonts table tbody td')) {
      td.classList.remove(...F)
      td.classList.add(id)
    }

    for (const weight of [100, 200, 300, 400, 500, 600, 700, 800, 900]) {
      if (face.weights.includes(weight)) {
        document.querySelector(`section#fonts table tbody tr.w${weight}`).classList.remove('hidden')
      } else {
        document.querySelector(`section#fonts table tbody tr.w${weight}`).classList.add('hidden')
      }
    }
  }
}

function initColors () {
  for (const li of document.querySelectorAll('section#colors > ul > li')) {
    const name = li.textContent.trim()
    const chip = document.createElement('div')
    chip.className = 'chip'
    chip.style.backgroundColor = `var(--${li.dataset.variable})`

    const label = document.createElement('div')
    label.className = 'label'
    label.innerHTML = `<span class="name"></span><code class="hex"></code><code class="variable"></code>`
    label.querySelector('.name').textContent = name
    label.querySelector('.hex').textContent = `#${li.dataset.hex}`
    label.querySelector('.variable').textContent = `var(--${li.dataset.variable})`

    li.replaceChildren(chip, label)
  }
}

function init () {
  initColors()

  for (const li of document.querySelectorAll('section#fonts header nav ul li')) {
    Faces.set(li.dataset.face, {
      id: li.dataset.face,
      name: li.textContent.trim(),
      weights: li.dataset.weights.split(' ').map(n => Number.parseInt(n)),
      styles: li.dataset.styles.split(' ')
    })

    if (li.classList.contains('selected')) {
      setFace(li.dataset.face)
    }

    li.querySelector('button').addEventListener('click', () => {
      const previous = document.querySelector('section#fonts header nav ul li.selected')
      previous.classList.remove('selected')
      previous.querySelector('button').setAttribute('aria-pressed', 'false')
      li.classList.add('selected')
      li.querySelector('button').setAttribute('aria-pressed', 'true')
      setFace(li.dataset.face)
    })
  }
}

init()
