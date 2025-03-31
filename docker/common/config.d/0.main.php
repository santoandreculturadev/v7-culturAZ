<?php 
use MapasCulturais\i;

 $_SERVER['SERVER_NAME'] = 'santoandre.sp.gov.br';

return [
    'app.siteName' => 'CulturAZ Santo André',
    'app.siteDescription' => 'CulturaZ Santo André',
   
    'app.geoDivisionsHierarchy' => [
        'bairro' => 'Bairro',
    ],

    // Define o tema ativo no site principal. Deve ser informado o namespace do tema e neste deve existir uma classe Theme.
    'themes.active' => 'MapasCulturais\Themes\BaseV2',

    // Ids dos selos verificadores. Para utilizar múltiplos selos informe os ids separados por vírgula.
    'app.verifiedSealsIds' => '1', 

];