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

function init () {
  for (const li of document.querySelectorAll('section#fonts header nav ul li')) {
    Faces.set(li.dataset.face, {
      id: li.dataset.face,
      name: li.textContent,
      weights: li.dataset.weights.split(' ').map(n => Number.parseInt(n)),
      styles: li.dataset.styles.split(' ')
    })

    if (li.classList.contains('selected')) {
      setFace(li.dataset.face)
    }

    li.addEventListener('click', e => {
      document.querySelector('section#fonts header nav ul li.selected').classList.remove('selected')
      e.target.classList.add('selected')
      setFace(e.target.dataset.face)
    })
  }
}

init()
